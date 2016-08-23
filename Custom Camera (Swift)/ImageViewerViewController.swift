//
//  ImageViewerViewController.swift
//  Custom Camera (Swift)
//
//  Created by Chris Leversuch on 03/07/2016.
//  Copyright © 2016 Brightec. All rights reserved.
//

import UIKit

class ImageViewerViewController: UIViewController {

    // MARK: Outlets
    @IBOutlet var imageView: UIImageView!

    // MARK: State
    var image: UIImage!

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = self.image
    }

}
