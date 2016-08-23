//
//  CameraViewController.swift
//  Custom Camera (Swift)
//
//  Created by Chris Leversuch on 03/07/2016.
//  Copyright © 2016 Brightec. All rights reserved.
//

import UIKit
import AVFoundation
import SnapKit


class CameraViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet var topBarView: UIView!
    @IBOutlet var bottomBarView: UIView!
    @IBOutlet var cameraContainerView: UIView!
    @IBOutlet var flashButton: UIButton!
    @IBOutlet var flashModeContainerView: UIView!
    @IBOutlet var flashAutoButton: UIButton!
    @IBOutlet var flashOnButton: UIButton!
    @IBOutlet var flashOffButton: UIButton!
    @IBOutlet var cameraButton: UIButton!
    @IBOutlet var openPhotoAlbumButton: UIButton!
    @IBOutlet var takePhotoButton: UIButton!
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var cameraViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var cameraViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet var bottomBarHeightConstraint: NSLayoutConstraint!

    // MARK: State
    var blurView: UIVisualEffectView!

    var session: AVCaptureSession!
    var capturePreviewView: UIView!
    var capturePreviewLayer: AVCaptureVideoPreviewLayer!
    var captureQueue: NSOperationQueue!
    var imageOrientation: UIImageOrientation!
    var flashMode: AVCaptureFlashMode! {
        didSet {
            updateFlashButton()
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Default to the flash mode buttons being hidden
        flashModeContainerView.alpha = 0.0

        // Initialise the capture queue
        captureQueue = NSOperationQueue()

        // Initialise the blur effect used when switching between cameras
        let effect = UIBlurEffect(style: .Light)
        blurView = UIVisualEffectView(effect: effect)

        // Listen for orientation changes so that we can update the UI
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(orientationChanged(_:)), name: UIDeviceOrientationDidChangeNotification, object: nil)

        // 3.5" and 4" devices have a smaller bottom bar
        if (CGRectGetHeight(UIScreen.mainScreen().bounds) <= 568.0) {
            bottomBarHeightConstraint.constant = 91.0
            bottomBarView.layoutIfNeeded()
        }

        // 3.5" devices have the top and bottom bars over the camera view
        if (CGRectGetHeight(UIScreen.mainScreen().bounds) == 480.0) {
            cameraViewTopConstraint.constant = -CGRectGetHeight(self.topBarView.frame)
            cameraViewBottomConstraint.constant = -CGRectGetHeight(self.bottomBarView.frame)
            cameraContainerView.layoutIfNeeded()
        }

        updateOrientation()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        enableCapture()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        captureQueue.cancelAllOperations()
        capturePreviewLayer.removeFromSuperlayer()
        for input in session.inputs {
            session.removeInput(input as! AVCaptureInput)
        }
        for output in session.outputs {
            session.removeOutput(output as! AVCaptureOutput)
        }
        session.stopRunning()
        session = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let capturePreviewLayer = capturePreviewLayer {
            capturePreviewLayer.frame = cameraContainerView.bounds
        }
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }

    override func shouldAutorotate() -> Bool {
        return false
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return .Portrait
    }


    // MARK: - UI

    func toggleFlashModeButtons() {
        UIView.animateWithDuration(0.3) {
            self.flashModeContainerView.alpha = self.flashModeContainerView.alpha == 1.0 ? 0.0 : 1.0
            self.cameraButton.alpha = self.cameraButton.alpha == 1.0 ? 0.0 : 1.0
        }
    }

    func updateFlashButton() {
        switch flashMode! {
        case .Auto:
            flashButton.setImage(UIImage(named: "ic_flash_auto_white"), forState: .Normal)
            break

        case .On:
            flashButton.setImage(UIImage(named: "ic_flash_on_white"), forState: .Normal)
            break

        case .Off:
            flashButton.setImage(UIImage(named: "ic_flash_off_white"), forState: .Normal)
            break
        }
    }

    func updateOrientation() {
        let deviceOrientation = UIDevice.currentDevice().orientation

        let angle: CGFloat
        switch deviceOrientation {
        case .PortraitUpsideDown:
            angle = CGFloat(M_PI)
            break

        case .LandscapeLeft:
            angle = CGFloat(M_PI_2)
            break

        case .LandscapeRight:
            angle = CGFloat(-M_PI_2)
            break

        default:
            angle = 0
            break
        }

        UIView.animateWithDuration(0.3) { 
            self.flashButton.transform = CGAffineTransformMakeRotation(angle)
            self.flashAutoButton.transform = CGAffineTransformMakeRotation(angle)
            self.flashOnButton.transform = CGAffineTransformMakeRotation(angle)
            self.flashOffButton.transform = CGAffineTransformMakeRotation(angle)
            self.cameraButton.transform = CGAffineTransformMakeRotation(angle)
            self.openPhotoAlbumButton.transform = CGAffineTransformMakeRotation(angle)
            self.takePhotoButton.transform = CGAffineTransformMakeRotation(angle)
            self.cancelButton.transform = CGAffineTransformMakeRotation(angle)
        }
    }


    // MARK: - Helpers

    func enableCapture() {
        if (session != nil) { return }

        self.flashButton.hidden = true
        self.cameraButton.hidden = true

        let operation = captureOperation()
        operation.completionBlock = {
            self.operationCompleted()
        }
        operation.queuePriority = .VeryHigh
        captureQueue.addOperation(operation)
    }

    func captureOperation() -> NSBlockOperation {
        let operation = NSBlockOperation {
            self.session = AVCaptureSession()
            self.session.sessionPreset = AVCaptureSessionPresetPhoto
            let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)

            let input: AVCaptureDeviceInput?
            do {
                input = try AVCaptureDeviceInput(device: device)
            } catch {
                input = nil
            }

            if (input == nil) { return }

            self.session.addInput(input)

            // Turn on point autofocus for middle of view
            do {
                try device.lockForConfiguration()
            } catch {
                return
            }

            if (device.isFocusModeSupported(.AutoFocus)) {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                device.focusMode = .ContinuousAutoFocus
            }

            if (device.isFlashModeSupported(.Auto)) {
                device.flashMode = .Auto
            } else {
                device.flashMode = .Off
            }
            self.flashMode = device.flashMode

            device.unlockForConfiguration()

            self.capturePreviewLayer = AVCaptureVideoPreviewLayer(session: self.session)
            self.capturePreviewLayer.frame = self.cameraContainerView.bounds
            self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill

            // Still Image Output
            let stillOutput = AVCaptureStillImageOutput()
            stillOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            self.session.addOutput(stillOutput)
        }

        return operation
    }

    func operationCompleted() {
        dispatch_async(dispatch_get_main_queue()) { 
            if (self.session == nil) { return }
            guard let device = self.currentDevice() else { return }

            self.capturePreviewView = UIView(frame: CGRect.zero)
            self.cameraContainerView.addSubview(self.capturePreviewView)
            self.capturePreviewView.snp_makeConstraints(closure: { (make) in
                make.edges.equalToSuperview()
            })
            self.capturePreviewView.layer.addSublayer(self.capturePreviewLayer)
            self.session.startRunning()
            if (device.hasFlash) {
                self.updateFlashlightState()
                self.flashButton.hidden = false
            }
            if (UIImagePickerController.isCameraDeviceAvailable(.Front) && UIImagePickerController.isCameraDeviceAvailable(.Rear)) {
                self.cameraButton.hidden = false
            }
        }
    }

    func updateFlashlightState() {
        guard let device = currentDevice() else { return }

        flashAutoButton.selected = flashMode == .Auto
        flashOnButton.selected = flashMode == .On
        flashOffButton.selected = flashMode == .Off

        do {
            try device.lockForConfiguration()
            device.flashMode = self.flashMode
            device.unlockForConfiguration()
        } catch {

        }
    }

    func currentDevice() -> AVCaptureDevice? {
        if (session == nil) { return nil }
        guard let inputDevice = session.inputs.first as? AVCaptureDeviceInput else { return nil }
        return inputDevice.device
    }

    func frontCamera() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in devices {
            let device = device as! AVCaptureDevice
            if (device.position == .Front) {
                return device
            }
        }

        return nil
    }

    func currentImageOrientation() -> UIImageOrientation {
        let deviceOrientation = UIDevice.currentDevice().orientation
        let imageOrientation: UIImageOrientation

        let input = session.inputs.first as! AVCaptureDeviceInput
        if (input.device.position == .Back) {
            switch (deviceOrientation) {
            case .LandscapeLeft:
                imageOrientation = .Up
                break

            case .LandscapeRight:
                imageOrientation = .Down
                break

            case .PortraitUpsideDown:
                imageOrientation = .Left
                break

            default:
                imageOrientation = .Right
                break
            }
        } else {
            switch (deviceOrientation) {
            case .LandscapeLeft:
                imageOrientation = .DownMirrored
                break

            case .LandscapeRight:
                imageOrientation = .UpMirrored
                break

            case .PortraitUpsideDown:
                imageOrientation = .RightMirrored
                break

            default:
                imageOrientation = .LeftMirrored
                break
            }
        }
        
        return imageOrientation
    }

    func takePicture() {
        if (!cameraButton.enabled) { return }

        let output = session.outputs.last as! AVCaptureStillImageOutput
        guard let videoConnection = output.connections.last as? AVCaptureConnection else {
            return
        }

        output.captureStillImageAsynchronouslyFromConnection(videoConnection) { (let imageDataSampleBuffer: CMSampleBuffer!, let error: NSError!) in
            self.cameraButton.enabled = true

            if (imageDataSampleBuffer == nil || error != nil) { return }

            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)

            let cgImage: CGImage = UIImage(data: imageData)!.CGImage!
            let image = UIImage(CGImage: cgImage, scale: 1.0, orientation: self.currentImageOrientation())

            self.handleImage(image)
        }

        cameraButton.enabled = false
    }

    func handleImage(image: UIImage) {
        let navController: UINavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("ImageViewerStoryboardIdentifier") as! UINavigationController

        let viewController: ImageViewerViewController = navController.viewControllers.first as! ImageViewerViewController
        viewController.image = image
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(doneBarButtonWasTouched(_:)))

        self.presentViewController(navController, animated: true, completion: nil)
    }


    // MARK: - Actions

    @IBAction func flashButtonWasTouched(sender: UIButton) {
        toggleFlashModeButtons()
    }

    @IBAction func flashModeButtonWasTouched(sender: UIButton) {
        if (sender == flashAutoButton) {
            flashMode = .Auto
        } else if (sender == flashOnButton) {
            flashMode = .On
        } else {
            flashMode = .Off
        }

        updateFlashlightState()
        
        toggleFlashModeButtons()
    }

    @IBAction func cameraButtonWasTouched(sender: UIButton) {
        if (session == nil) { return }
        session.stopRunning()

        // Input Switch
        let operation = NSBlockOperation {
            var input = self.session.inputs.first as! AVCaptureDeviceInput

            let newCamera: AVCaptureDevice

            if (input.device.position == .Back) {
                newCamera = self.frontCamera()!
            } else {
                newCamera = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
            }

            // Should the flash button still be displayed?
            dispatch_async(dispatch_get_main_queue(), {
                self.flashButton.hidden = !newCamera.flashAvailable
            })

            // Remove previous camera, and add new
            self.session.removeInput(input)

            do {
                try input = AVCaptureDeviceInput(device: newCamera)
            } catch {
                return
            }
            self.session.addInput(input)
        }
        operation.completionBlock = {
            dispatch_async(dispatch_get_main_queue(), {
                if (self.session == nil) { return }
                self.session.startRunning()
                self.blurView.removeFromSuperview()
            })
        }
        operation.queuePriority = .VeryHigh

        // disable button to avoid crash if the user spams the button
        self.cameraButton.enabled = false

        // Add blur to avoid flickering
        self.blurView.hidden = false
        self.capturePreviewView.addSubview(self.blurView)
        self.blurView.snp_makeConstraints(closure: { (make) in
            make.edges.equalToSuperview()
        })

        // Flip Animation
        UIView.transitionWithView(self.capturePreviewView, duration: 0.5, options: [.TransitionFlipFromLeft, .AllowAnimatedContent], animations: nil) { (finished) in
            self.cameraButton.enabled = true
            self.captureQueue.addOperation(operation)
        }
    }

    @IBAction func openPhotoAlbumButtonWasTouched(sender: UIButton) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .PhotoLibrary
        imagePickerController.delegate = self

        presentViewController(imagePickerController, animated: true, completion: nil)
    }

    @IBAction func takePhotoButtonWasTouchedz(sender: UIButton) {
        takePicture()
    }

    @IBAction func cancelButtonWasTouched(sender: UIButton) {
        dismissViewControllerAnimated(true, completion: nil)
    }

    func orientationChanged(sender: NSNotification) {
        updateOrientation()
    }

    func doneBarButtonWasTouched(sender: UIBarButtonItem) {
        dismissViewControllerAnimated(true, completion: nil)
    }

}


// MARK: - UIImagePickerControllerDelegate
extension CameraViewController: UIImagePickerControllerDelegate {

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage

        dismissViewControllerAnimated(true) { 
            self.handleImage(image)
        }
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }

}


// MARK: - UINavigationControllerDelegate
extension CameraViewController: UINavigationControllerDelegate {

}

