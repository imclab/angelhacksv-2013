#include "utils.h"
#include <fstream>
#include "MainGazeTracker.h"
#import <Cocoa/Cocoa.h>
#import "LCGazeFoundation.h"
#import "LCGazePoint.h"

class VideoWriter {
  CvVideoWriter *video;
public:
    VideoWriter(CvSize size) :
  video(cvCreateVideoWriter("out.avi", 0x58564944, 15.0, size))
    {}

  void write(const IplImage *image) {
    cvWriteFrame(video, image);
  }

  ~VideoWriter() {
    cvReleaseVideoWriter(&video);
  }
};

CommandLineArguments::CommandLineArguments(int argc, char** argv) {
  for(int i=1; i<argc; i++) {
    if (argv[i][0] == '-')
      options.push_back(argv[i]);
    else
      parameters.push_back(argv[i]);
  }
}

bool CommandLineArguments::isoption(const char* option) {
  xforeach(iter, options)
    if (!strcmp(*iter, option))
      return true;
    return false;
}

VideoInput::VideoInput():
  capture(cvCaptureFromCAM(0)), framecount(0),
  frame(cvQueryFrame(capture)), size(cvSize(frame->width, frame->height))
{}

VideoInput::VideoInput(const char* filename):
//    capture(cvCaptureFromFile(filename)), framecount(0),
  capture(cvCaptureFromCAM(0)), framecount(0),
  frame(cvQueryFrame(capture)), size(cvSize(frame->width, frame->height))
{}

void VideoInput::updateFrame() {
  framecount++;
  frame = cvQueryFrame(capture);
}

VideoInput::~VideoInput() {
  cvReleaseCapture( &capture );
}

MainGazeTracker::MainGazeTracker(int argc, char** argv,
         const vector<shared_ptr<AbstractStore> >
         &stores, NSView *hostView):
    framestoreload(-1), stores(stores), autoreload(false)
{
  CommandLineArguments args(argc, argv);
  appView = hostView;

  if (args.parameters.size() == 0) {
    videoinput.reset(new VideoInput());
    if (args.isoption("--record"))
        video.reset(new VideoWriter(videoinput->size));
  }
  else {
    videoinput.reset(new VideoInput(args.parameters[0]));
  }

  canvas.reset(cvCreateImage(videoinput->size, 8, 3));
  tracking.reset(new TrackingSystem(videoinput->size));
}

void MainGazeTracker::addTracker(OpenGazer::Point point) {
  tracking->tracker.addtracker(point);
}

void MainGazeTracker::savepoints() {
  try {
    tracking->tracker.save("tracker", "points.txt", videoinput->frame);
    autoreload = true;
  }
  catch (ios_base::failure &e) {
    cout << e.what() << endl;
  }
}

void MainGazeTracker::loadpoints() {
  try {
    tracking->tracker.load("tracker", "points.txt", videoinput->frame);
    autoreload = true;
  }
  catch (ios_base::failure &e) {
    cout << e.what() << endl;
  }
}

void MainGazeTracker::clearpoints() {
  tracking->tracker.cleartrackers();
  autoreload = false;
}

void MainGazeTracker::doprocessing(void) {
  framecount++;
  videoinput->updateFrame();
  const IplImage *frame = videoinput->frame;

  if (video.get())
    video->write(frame);

  canvas->origin = frame->origin;
  cvCopy(frame, canvas.get(), 0);

  try {
    tracking->doprocessing(frame, canvas.get());

    // This is where the gaze tracking output can be grabbed
    // It is stored in: tracking->gazetracker.output.gazepoint (output is a TrackerOutput struct)
    if (tracking->gazetracker.isActive()) {
      xforeach(iter, stores)
      (*iter)->store(tracking->gazetracker.output);
//        LCGazePoint* point = [[LCGazePoint alloc] init];
//        point.x = tracking->gazetracker.output.gazepoint.x;
//        point.y = tracking->gazetracker.output.gazepoint.y;
//        NSLog(@"GazePoint: %@", point);
        NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat: tracking->gazetracker.output.gazepoint.x ],kGazePointXKey, [NSNumber numberWithFloat:tracking->gazetracker.output.gazepoint.y], kGazePointYKey, nil];
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kGazePointNotification object:kGazeSenderID userInfo:dict deliverImmediately: YES];
       // NSLog(@"Notification Sent");
        //printf("Gaze: %f %f\n", tracking->gazetracker.output.gazepoint.x, tracking->gazetracker.output.gazepoint.y);
    }
//  if (!tracking->tracker.areallpointsactive())
//      throw TrackingException();
    framestoreload = 20;
  }
  catch (TrackingException&) {
    framestoreload--;
  }

  framefunctions.process();
//     statemachine.handleEvent(EVENT_TICK);

  if (autoreload && framestoreload <= 0)
    loadpoints();
}


MainGazeTracker::~MainGazeTracker(void) {
}


void MainGazeTracker::addExemplar(OpenGazer::Point exemplar) {
  if (exemplar.x >= EyeExtractor::eyedx &&
      exemplar.x + EyeExtractor::eyedx < videoinput->size.width &&
      exemplar.y >= EyeExtractor::eyedy &&
      exemplar.y + EyeExtractor::eyedy < videoinput->size.height)
    tracking->gazetracker.addExemplar(exemplar,
                                      tracking->eyex.eyefloat.get(),
                                      tracking->eyex.eyegrey.get());
}

static vector<OpenGazer::Point> scalebyscreen(const vector<OpenGazer::Point> &points) {
  NSRect screenRect = [[NSScreen mainScreen] frame];
    int screenX = (int)screenRect.size.width;
    int screenY = (int)screenRect.size.height;
  return Calibrator::scaled(points, screenX, screenY);
}

void MainGazeTracker::startCalibration() {
  //printf("startCalibration signal received\n");
  shared_ptr<WindowPointer>
  pointer(new WindowPointer(WindowPointer::PointerSpec(appView, 60,60,255,0,0)));
  ifstream calfile("calpoints.txt");

  shared_ptr<Calibrator>
  calibrator(new Calibrator(framecount, tracking,
          scalebyscreen(Calibrator::loadpoints(calfile)),
          pointer));

  framefunctions.clear();
  framefunctions.addchild(&framefunctions, calibrator);
}

void MainGazeTracker::startTesting() {
  vector<OpenGazer::Point> points;
  for(double x=0.2; x<0.9; x+=0.2)
    for(double y=0.2; y<0.9; y+=0.2)
      points.push_back(OpenGazer::Point(x,y));

  shared_ptr<WindowPointer>
  pointer(new WindowPointer(WindowPointer::PointerSpec(appView, 60,60,0,255,0)));

  shared_ptr<MovingTarget>
  moving(new MovingTarget(framecount, scalebyscreen(points), pointer));

  framefunctions.clear();
  framefunctions.addchild(&framefunctions, moving);
}
