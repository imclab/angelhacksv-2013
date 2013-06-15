#include "Calibrator.h"

Calibrator::~Calibrator() {
#ifdef DEBUG
    cout << "Destroying calibrator" << endl;
#endif
}

FrameFunction::~FrameFunction() {
#ifdef DEBUG
    cout << "Destroying framefunction" << endl;
#endif
}

MovingTarget::MovingTarget(const int &frameno,
         const vector<OpenGazer::Point>& points,
         const shared_ptr<WindowPointer> &pointer,
         int dwelltime):
    FrameFunction(frameno),
    points(points), dwelltime(dwelltime), pointer(pointer)
{
};

MovingTarget::~MovingTarget() {
    int id = getFrame() / dwelltime;
}

void MovingTarget::process() {
    if (active()) {
  int id = getPointNo();
  if (getPointFrame() == 1)
      pointer->setPosition(points[id].x, points[id].y);
    }
    else
  detach();
}

bool MovingTarget::active() {
    return getPointNo() < (int) points.size();
}

void MovingTarget::killPoint() {
    pointer->hide();
}

int MovingTarget::getPointNo() {
    return getFrame() / dwelltime;
}

int MovingTarget::getPointFrame() {
    return getFrame() % dwelltime;
}

Calibrator::Calibrator(const int &framecount,
           const shared_ptr<TrackingSystem> &trackingsystem,
           const vector<OpenGazer::Point>& points,
           const shared_ptr<WindowPointer> &pointer,
           int dwelltime):
    MovingTarget(framecount, points, pointer, dwelltime),
    trackingsystem(trackingsystem)
{
    trackingsystem->gazetracker.clear();
    // todo: remove all calibration points
}


void Calibrator::process() {
  if (active()) {
    int id = getPointNo();
    int frame = getPointFrame();
    if (frame == 1) // start
      averageeye.reset(new FeatureDetector(EyeExtractor::eyesize));
    if (frame >= dwelltime/2) // middle
        averageeye->addSample(trackingsystem->eyex.eyefloat.get());
    if (frame == dwelltime-1) { // end
        trackingsystem->gazetracker.
      addExemplar(points[id], averageeye->getMean().get(),
            trackingsystem->eyex.eyegrey.get());
    }
    MovingTarget::process();
  } else {
    MovingTarget::process();
    MovingTarget::killPoint();
  }
}
// version 3A
 const OpenGazer::Point Calibrator::defaultpointarr[] = {OpenGazer::Point(0.5, 0.5), 
 OpenGazer::Point(0.05, 0.5), OpenGazer::Point(0.95, 0.5),
 OpenGazer::Point(0.5, 0.05), OpenGazer::Point(0.5, 0.95), 
 OpenGazer::Point(0.05, 0.05), OpenGazer::Point(0.05, 0.95), 
 OpenGazer::Point(0.95, 0.95), OpenGazer::Point(0.95, 0.05), 
 OpenGazer::Point(0.33, 0.33), OpenGazer::Point(0.33, 0.66), 
 OpenGazer::Point(0.66, 0.66), OpenGazer::Point(0.66, 0.33),
 OpenGazer::Point(0.05, 0.5), OpenGazer::Point(0.97, 0.3),
 OpenGazer::Point(0.5, 0.05), OpenGazer::Point(0.5, 0.95), 
 OpenGazer::Point(0.05, 0.05), OpenGazer::Point(0.05, 0.95), 
 OpenGazer::Point(0.97, 0.97), OpenGazer::Point(0.97, 0.03), 
 OpenGazer::Point(0.25, 0.25), OpenGazer::Point(0.25, 0.75), 
 OpenGazer::Point(0.75, 0.75), OpenGazer::Point(0.75, 0.25)};

/* version 0.1
 const OpenGazer::Point Calibrator::defaultpointarr[] = {OpenGazer::Point(0.5, 0.5), 
    OpenGazer::Point(0.1, 0.5), OpenGazer::Point(0.9, 0.5),
    OpenGazer::Point(0.5, 0.1), OpenGazer::Point(0.5, 0.9), 
    OpenGazer::Point(0.1, 0.1), OpenGazer::Point(0.1, 0.9), 
    OpenGazer::Point(0.9, 0.9), OpenGazer::Point(0.9, 0.1), 
    OpenGazer::Point(0.33, 0.33), OpenGazer::Point(0.33, 0.66), 
    OpenGazer::Point(0.66, 0.66), OpenGazer::Point(0.66, 0.33),
    OpenGazer::Point(0.05, 0.5), OpenGazer::Point(0.95, 0.5),
    OpenGazer::Point(0.5, 0.05), OpenGazer::Point(0.5, 0.95), 
    OpenGazer::Point(0.05, 0.05), OpenGazer::Point(0.05, 0.95), 
    OpenGazer::Point(0.95, 0.95), OpenGazer::Point(0.95, 0.05), 
    OpenGazer::Point(0.25, 0.25), OpenGazer::Point(0.25, 0.75), 
    OpenGazer::Point(0.75, 0.75), OpenGazer::Point(0.75, 0.25)};
*/
/*
// Version 2C
const OpenGazer::Point Calibrator::defaultpointarr[] = {
    OpenGazer::Point(0.5, 0.5), // 1  
    OpenGazer::Point(0.6, 0.99), // 2  
    OpenGazer::Point(0.7, 0.8), // 3  
    OpenGazer::Point(0.8, 0.99), // 4  
    OpenGazer::Point(0.99, 0.75), // 5  
    OpenGazer::Point(0.85, 0.8), // 6  
    OpenGazer::Point(0.99, 0.99), // 7  
    OpenGazer::Point(0.85, 0.5), // 8  
    OpenGazer::Point(0.99, 0.99), // 9  
    OpenGazer::Point(0.8, 0.05), // 10  
    OpenGazer::Point(0.99, 0.25), // 11 
    OpenGazer::Point(0.85, 0.2), // 12  
    OpenGazer::Point(0.99, 0.05), // 13  
    OpenGazer::Point(0.7, 0.2), // 14  
    OpenGazer::Point(0.6, 0.05), // 15  
    OpenGazer::Point(0.68, 0.5), // 16  
    OpenGazer::Point(0.5, 0.2), // 17  
    OpenGazer::Point(0.4, 0.05), // 18  
    OpenGazer::Point(0.3, 0.2), // 19  
    OpenGazer::Point(0.23, 0.05), // 20  
    OpenGazer::Point(0.05, 0.25), // 21  
    OpenGazer::Point(0.15, 0.2), // 22  
    OpenGazer::Point(0.05, 0.05), // 23  
    OpenGazer::Point(0.15, 0.5), // 24 
    OpenGazer::Point(0.5, 0.5), // 25  
    OpenGazer::Point(0.23, 0.99), // 26  
    OpenGazer::Point(0.05, 0.75), // 27  
    OpenGazer::Point(0.15, 0.8), // 28  
    OpenGazer::Point(0.05, 0.99), // 29  
    OpenGazer::Point(0.3, 0.8), // 30  
    OpenGazer::Point(0.4, 0.99), // 31  
    OpenGazer::Point(0.33, 0.5), // 32  
    OpenGazer::Point(0.5, 0.8)}; // 33  
*/    
 
vector<OpenGazer::Point>
Calibrator::defaultpoints(Calibrator::defaultpointarr,
        Calibrator::defaultpointarr+
        (sizeof(Calibrator::defaultpointarr) /
         sizeof(Calibrator::defaultpointarr[0])));

vector<OpenGazer::Point> Calibrator::loadpoints(istream& in) {
  vector<OpenGazer::Point> result;

  for(;;) {
    double x, y;
    in >> x >> y;
    if (in.rdstate()) break; // break if any error
    result.push_back(OpenGazer::Point(x, y));
  }

  // [RYAN]: ignoring the istream, which probably is null or something
  // return result;
  return Calibrator::defaultpoints;
}

vector<OpenGazer::Point> Calibrator::scaled(const vector<OpenGazer::Point> &points,
              double x, double y)
{
//     double dx = x > y ? (x-y)/2 : 0.0;
//     double dy = y > x ? (y-x)/2 : 0.0;
//     double scale = x > y ? y : x;

  vector<OpenGazer::Point> result;

  xforeach(iter, points)
    result.push_back(OpenGazer::Point(iter->x * x, iter->y * y));
//  result.push_back(OpenGazer::Point(iter->x * scale + dx, iter->y * scale + dy));

  return result;
}
