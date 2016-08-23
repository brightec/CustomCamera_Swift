//
//  ViewController.swift
//  Custom Camera (Swift)
//
//  Created by Chris Leversuch on 03/07/2016.
//  Copyright © 2016 Brightec. All rights reserved.
//

import UIKit


class InitialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    func showNativeCamera() {
        if (!UIImagePickerController.isSourceTypeAvailable(.Camera)) {
            showNoCameraError()
            return
        }

        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .Camera
        imagePickerController.delegate = self

        presentViewController(imagePickerController, animated: true, completion: nil);
    }

    func showCustomCamera() {
        if (!UIImagePickerController.isSourceTypeAvailable(.Camera)) {
            showNoCameraError()
            return
        }

        let cameraViewController: CameraViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("CameraStoryboardIdentifier") as! CameraViewController
        presentViewController(cameraViewController, animated: true, completion: nil)
    }

    func showNoCameraError() {
        let alertController = UIAlertController(title: "Error", message: "Your device doesn't have a camera", preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: - Actions
    @IBAction func showNativeCameraButtonWasTouched(sender: UIButton) {
        showNativeCamera()
    }

    @IBAction func showCustomCameraButtonWasTouched(sender: UIButton) {
        showCustomCamera()
    }

    func doneBarButtonWasTouched(sender: UIBarButtonItem) {
        dismissViewControllerAnimated(true, completion: nil)
    }

}


// MARK: - UIImagePickerControllerDelegate
extension InitialViewController: UIImagePickerControllerDelegate {

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let image: UIImage = info[UIImagePickerControllerOriginalImage] as! UIImage;

        dismissViewControllerAnimated(true) {
            let navController: UINavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("ImageViewerStoryboardIdentifier") as! UINavigationController

            let viewController: ImageViewerViewController = navController.viewControllers.first as! ImageViewerViewController
            viewController.image = image
            viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: #selector(self.doneBarButtonWasTouched(_:)))

            self.presentViewController(navController, animated: true, completion: nil)
        }
    }

    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
    }

}


// MARK: - UINavigationControllerDelegate
extension InitialViewController: UINavigationControllerDelegate {
}

