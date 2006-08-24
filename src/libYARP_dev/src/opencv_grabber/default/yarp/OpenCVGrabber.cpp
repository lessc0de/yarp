// -*- mode:C++; tab-width:4; c-basic-offset:4; indent-tabs-mode:nil -*-

/*
 * A Yarp 2 frame grabber device driver using OpenCV to implement
 * image capture from cameras and AVI files.
 *
 * Eric Mislivec
 */


// This define prevents Yarp from declaring its own copy of IplImage
// which OpenCV provides as well. Since Yarp's Image class depends on
// IplImage, we need to define this, then include the OpenCV headers
// before Yarp's.
#define YARP_CVTYPES_H_


#include <opencv/cv.h>
#include <opencv/highgui.h>

#include <yarp/String.h>

#include <yarp/dev/Drivers.h>
#include <yarp/dev/FrameGrabberInterfaces.h>
#include <yarp/dev/PolyDriver.h>

#include <yarp/os/ConstString.h>
#include <yarp/os/Property.h>
#include <yarp/os/Network.h>
#include <yarp/os/Searchable.h>
#include <yarp/os/Value.h>

#include <yarp/sig/Image.h>


#include <stdio.h>

#include <yarp/OpenCVGrabber.h>


// Explicitly declare the types we are using after all includes
using yarp::String;

using yarp::dev::DeviceDriver;
using yarp::dev::DriverCreatorOf;
using yarp::dev::Drivers;
using yarp::dev::IFrameGrabberImage;
using yarp::dev::PolyDriver;

using yarp::os::ConstString;
using yarp::os::Network;
using yarp::os::Property;
using yarp::os::Searchable;
using yarp::os::Value;

using yarp::sig::ImageOf;
using yarp::sig::PixelRgb;

using namespace yarp::os;
using namespace yarp::sig;
using namespace yarp::dev;



bool OpenCVGrabber::open(Searchable & config) {

    // Release any previously allocated resources, just in case
    close();


    // Are we capturing from a file or a camera ?
    bool fromFile = config.check("file");
    if (fromFile) {

        ConstString file = config.check("file", Value("")).asString();
        if ("" == file) {
            printf("No file name specified!\n");
            return false;
        }

        // Try to open a capture object for the file
        m_capture = (void*)cvCaptureFromAVI(file.c_str());
        if (0 == m_capture) {
            printf("Unable to open file '%s' for capture!\n",
                   file.c_str());
            return false;
        }

    } else {

        // Try to open a capture object for the first camera
        m_capture = (void*)cvCaptureFromCAM(-1);
        if (0 == m_capture) {
            printf("Unable to open camera for capture!\n");
            return false;
        }

    }


    // Extract the desired image size from the configuration if
    // present, otherwise query the capture device
    if (config.check("w")) {
        m_w = config.check("w", Value(-1)).asInt();
    } else {
        m_w = (int)cvGetCaptureProperty((CvCapture*)m_capture,
                                        CV_CAP_PROP_FRAME_WIDTH);
    }

    if (config.check("h")) {
        m_h = config.check("h", Value(-1)).asInt();
    } else {
        m_h = (int)cvGetCaptureProperty((CvCapture*)m_capture,
                                        CV_CAP_PROP_FRAME_HEIGHT);
    }


    // Ignore capture properties - they are unreliable
    //printf("Capture properties: %ld x %ld pixels @ %lf frames/sec.\n",
    //     m_w, m_h, cvGetCaptureProperty(m_capture, CV_CAP_PROP_FPS));

    // Success!
    return true;

}


/**
 * Close a grabber. This is called by yarp to free any allocated
 * hardware or software resources when the driver instance is no
 * longer needed.
 *
 * @return True if the device was successfully closed. In any case
 * the device will be unusable after this function is called.
 */
bool OpenCVGrabber::close() {
    // Release the capture object, the pointer should be set null
    if (0 != m_capture) cvReleaseCapture((CvCapture**)(&m_capture));
    if (0 != m_capture) {
        m_capture = 0; return false;
    } else return true;
}



/**
 * Read an image from the grabber.
 *
 * @param image The image to read. The image will be resized to
 * the dimensions the grabber is using, and the captured image
 * data will be written to it.
 *
 * @return True if an image was successfully captured. If false
 * returned, the image will be resized to the dimensions used by
 * the grabber, but all pixels will be zeroed.
 */
bool OpenCVGrabber::getImage(ImageOf<PixelRgb> & image) {

    // Must have a capture object
    if (0 == m_capture) {
        image.zero(); return false;
    }

    // Grab and retrieve a frame, OpenCV owns the returned image
    IplImage * iplFrame = cvQueryFrame((CvCapture*)m_capture);
    if (0 == iplFrame) {
        image.zero(); return false;
    }

    // Resize the output image, this should not result in new
    // memory allocation if the image is already the correct size
    image.resize(iplFrame->width, iplFrame->height);

    // Get an IplImage, the Yarp Image owns the memory pointed to
    IplImage * iplImage = (IplImage*)image.getIplImage();

    // Copy the captured image to the output image, flipping it if
    // the coordinate origin is not the top left
    if (IPL_ORIGIN_TL == iplFrame->origin)
        cvCopy(iplFrame, iplImage, 0);
    else
        cvFlip(iplFrame, iplImage, 0);

    if (iplFrame->channelSeq[0]=='B') {
        cvCvtColor(iplImage, iplImage, CV_BGR2RGB);
    }

    printf("%d by %d %s image\n", image.width(), image.height(),
           iplFrame->channelSeq);
    // That's it
    return true;

}





/**
 * Test program for the OpenCV based image grabber driver.
 *
 * @param argc Length of the argv array.
 * @param argv Canonical command-line argumnent array.
 */
/*
  int main(int argc, char ** argv)
  {
  // Initialize the network system, some platforms need this
  Network::init();


  // Give Yarp a factory for creating OpenCV grabbers
  Drivers::factory().add(new DriverCreatorOf<OpenCVGrabber>("opencv_grabber",
  "grabber",
  "OpenCVGrabber"));

  // Get a property container from the command line args
  Property config;
  config.fromCommand(argc, argv);
  // Add some values that will always be present
  config.put("device", "grabber");
  config.put("subdevice", "opencv_grabber");
  // Require a port name on the command line
  if ( ! config.check("name")) {
  printf("Please specify a port name: test_cv_grabber --name /port\n");
  return 1;
  }


  // Create a networked driver wrapper for an OpenCV grabber
  PolyDriver poly(config);
  if ( ! poly.isValid()) {
  printf("Device cration and configuration failed!\n");
  return 1;
  }

  // Let the device run until a key is pressed
  printf("Network device is active...\n");
  getchar();


  // Network finalization
  Network::fini();

  printf("Exiting...\n");
  return 0;

  }
*/

// End: OpenCVGrabber.cpp
