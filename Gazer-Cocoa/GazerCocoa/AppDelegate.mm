//
//  AppDelegate.m
//  com.labcogs.gazercocoa
//
//  Created by Ryan Kabir on 11/22/11.
//  Copyright (c) 2011 Lab Cogs Co. All rights reserved.
//

#import "AppDelegate.h"
#import <Carbon/Carbon.h>

#import "CoreFoundation/CoreFoundation.h"
#import "LCCalibrationPoint.h"
#import "DDHotKeyCenter.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize gazeTrackingRunning;
@synthesize runHeadless = _runHeadless;
@synthesize gazeTrackerStatus = _gazeTrackerStatus;

-(void)applicationWillFinishLaunching:(NSNotification*)aNotification{
    self.gazeTrackingRunning = NO; // Gaze tracking is not active
    self.gazeTrackerStatus = kGazeTrackerUncalibrated;
    // Whether we should launch the GUI on start
    self.runHeadless = NO; // No, run in background
    
    #ifdef CONFIGURATION_Debug_GUI
    NSLog(@"Launching with GUI");
        self.runHeadless = NO; // Launch the GUI on start
    #endif

    
    SInt32 OSXversionMajor, OSXversionMinor;
    if(Gestalt(gestaltSystemVersionMajor, &OSXversionMajor) == noErr && Gestalt(gestaltSystemVersionMinor, &OSXversionMinor) == noErr)
    {
        if(OSXversionMajor == 10 && OSXversionMinor >= 7)
        {
            [[NSApplication sharedApplication] disableRelaunchOnLogin];
        }else{
           
        }
    }
    
    [NSApp setPresentationOptions:(NSApplicationPresentationAutoHideMenuBar + NSApplicationPresentationAutoHideDock)];

    gazeWindowController = [[LCGazeTrackerWindowController alloc] initWithScreen:[NSScreen mainScreen]];
     calibrationWindowController = [[LCCalibrationWindowController alloc] initWithWindowNibName:@"CalibrationWindow"];

    // Local Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moveCalibrationPoint:)
                                                 name:@"changeCalibrationTarget"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(calibrationClosed:)
                                                 name:kLCGazeCalibrationUIClosed
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(finishedCalibration:)
                                                 name:kGrazeTrackerCalibrationEnded
                                               object:kGazeSenderID];
    
    // Inter process notifications (Distributed)
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(calibrationStarted:)
                                                 name:kGazeTrackerCalibrationStarted
                                               object:kGazeSenderID];


    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(terminationRequested:)
                                                            name:kGazeTrackerTerminateRequest
                                                          object:kGazeSenderID];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(calibrationStartRequested:)
                                                            name:kGazeTrackerCalibrationRequestStart
                                                          object:kGazeSenderID];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{  // set the right path so the classifiers can find their data

    // Broadcast to other apps that we're up and running
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kGazeTrackerReady
                                                                   object:kGazeSenderID
                                                                 userInfo:[NSDictionary dictionaryWithObject:kGazeTrackerUncalibrated forKey:kGazeTrackerStatusKey]
                                                        deliverImmediately: YES];
    if(!self.runHeadless){
        [self launchCalibrationGUI];
    }
    [[[DDHotKeyCenter alloc] init] registerHotKeyWithKeyCode:kVK_ANSI_G 
                                               modifierFlags:(NSCommandKeyMask | NSControlKeyMask)  
                                                      target:self 
                                                      action:@selector(toggleGazeTarget:) 
                                                      object:nil];
    NSLog(@"GazerCocoa finished launching");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification{
    NSLog(@"GazerCocoa will terminate");
    // Delist ourself from receiving distributed notifications
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];

    // Tell other apps we're shutting down
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kGazeTrackerTerminating
                                                                   object:kGazeSenderID
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}


#pragma mark - OpenCV

#ifdef CONFIGURATION_Debug_OpenCV
    MainGazeTracker *gazeTracker;
// this is only used for debugging
void mouseClick(int event, int x, int y, int flags, void* param) {
    if(event == CV_EVENT_LBUTTONDOWN || event == CV_EVENT_LBUTTONDBLCLK) {
        OpenGazer::Point point(x, y);
        PointTracker &tracker = gazeTracker->tracking->tracker;
        int closest = tracker.getClosestTracker(point);
        int lastPointId;

        if(closest >= 0 && point.distance(tracker.currentpoints[closest]) <= 10) lastPointId = closest;
        else
            lastPointId = -1;

        if(event == CV_EVENT_LBUTTONDOWN) {
            if(lastPointId >= 0) tracker.updatetracker(lastPointId, point);
            else {
                tracker.addtracker(point);
            }
        }
        if(event == CV_EVENT_LBUTTONDBLCLK) {
            if(lastPointId >= 0) tracker.removetracker(lastPointId);
        }
    }
}

#endif

-(void)launchGazeTracking{
    if(!self.gazeTrackingRunning);

    self.gazeTrackingRunning = YES;
        CFBundleRef mainBundle = CFBundleGetMainBundle();
        CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
        char path[PATH_MAX];
        if (!CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8 *)path, PATH_MAX))
        {
            // error!
        }
        CFRelease(resourcesURL);
        chdir(path);
        // end path settings

        gazerCocoaBridge = new GazerCocoaBridge::GazerCocoaBridge(0, NULL, calibrationWindowController.hostView);
        int status = gazerCocoaBridge->loadClassifiers();

        gazeTracker = gazerCocoaBridge->gazeTracker;
        calibrationWindowController.gazerCocoaBridgePointer = [NSValue valueWithPointer:gazerCocoaBridge];




#ifdef CONFIGURATION_Debug_OpenCV
        NSLog(@"\n\n  FYI - OpenCV debug is enabled\n\n");
        cvNamedWindow(MAIN_WINDOW_NAME, CV_GUI_EXPANDED);
        cvResizeWindow(MAIN_WINDOW_NAME, 640, 480);
        //    createButtons();
        cvSetMouseCallback(MAIN_WINDOW_NAME, mouseClick, NULL);
#endif

    gazeTracker->doprocessing();

#ifdef CONFIGURATION_Debug_OpenCV
        gazerCocoaBridge->drawFrame();
#endif

    // to declare an object Object* blah = &gazeTracker

    GlobalManager *gm = [GlobalManager sharedGlobalManager];
    gm.calibrationFlag = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0), ^{ // Run on a background thread - dispatch_get_main_queue()
        int count = 0;
        while(1) {
            gazeTracker->doprocessing();

            #ifdef CONFIGURATION_Debug_OpenCV
                gazerCocoaBridge->drawFrame();
            #endif

            if (gm.calibrationFlag) {
                gazeTracker->startCalibration();
                gm.calibrationFlag = NO;
            }
            // [RYAN] I think this line inserts a kind of delay into the loop
            // which in turn makes the calibration dot animate at a more human speed.
            // maybe can replace this with [nano]sleep call or something.
            char c = cvWaitKey(33);
            if (count==25) {
                NSLog(@"finding Eyes");
                gazerCocoaBridge->findEyes();
            }
            count = count + 1;
        }
        self.gazeTrackingRunning = NO;
    });
}

#pragma mark - Calibration

-(void)launchCalibrationGUI{
    NSLog(@"Launch the GUI");
    [self showCalibration];
    [self launchGazeTracking];
}

// [DAVE] This is a hack, doesn't support multiple re-calibration attempts
-(void)showCalibration{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [calibrationWindowController awakeFromNib];
}

#pragma mark - Notifications

-(void)moveCalibrationPoint:(NSNotification*)note{
    //NSLog(@"Receive move calibration Point");
    NSPoint point = [(NSValue*)[(NSDictionary*)[note userInfo] objectForKey:@"point"] pointValue];
    LCCalibrationPoint* calibrationPoint = [[LCCalibrationPoint alloc] init];
    //NSLog(@"Points: %f %f", point.x, point.y);
    calibrationPoint.x = point.x;
    calibrationPoint.y = point.y;
    [calibrationWindowController moveToNextPoint:calibrationPoint];
    [gazeWindowController setHotspot:calibrationPoint];
}

// The calibration process has started
-(void)calibrationStarted:(NSNotification*)note{
    NSLog(@"Notification :: Calibration Started");
    [gazeWindowController show:YES];
    gazeWindowController.trackHotspot = YES;
}

// There was a request to show the calibration GUI and such
-(void)calibrationStartRequested:(NSNotification*)note{
    NSLog(@"Notification :: Calibration Requested");
    [self launchCalibrationGUI];
}

// The calibration process ended, wbut we'll still show a GUI with the results
-(void)finishedCalibration:(NSNotification*)note{
    NSLog(@"Notification :: Calibration Finished");
    self.gazeTrackerStatus = kGazeTrackerCalibrated;
    //gazeWindowController.trackHotspot = NO;
    [calibrationWindowController finishCalibration:self.gazeTrackerStatus];
}

// Called when the user closes the calibration interface
-(void) calibrationClosed:(NSNotification*)note{
    NSLog(@"Notification :: Calibration UI Closed");

    // Close the Gaze Target window
    [gazeWindowController show:NO];
    // Resign focus
    //[[NSApplication sharedApplication] hide:self];

    // Send out a note that we've finished calibrating with the current status of the gaze tracker
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:kGrazeTrackerCalibrationEnded
                                                                   object:kGazeSenderID
                                                                 userInfo:[NSDictionary dictionaryWithObject:self.gazeTrackerStatus forKey:kGazeTrackerStatusKey]
                                                       deliverImmediately:YES];
}

-(void)terminationRequested:(NSNotification*)note{
    NSLog(@"Notification :: Termination requested");
    [[NSApplication sharedApplication] terminate:self];
}

-(void)toggleGazeTarget:(NSEvent*)hotKeyEvent{
    NSLog(@"HotKey :: Gaze Target estimation being toggled");
    if(gazeWindowController != nil){
        [gazeWindowController show:!gazeWindowController.isActive];
    }
}

@end
