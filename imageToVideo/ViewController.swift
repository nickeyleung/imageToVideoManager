//
//  ViewController.swift
//  imageToVideo
//
//  Created by admin on 2021/5/18.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let image = UIImage(named: "4")
        let image2 = UIImage(named: "5")
        let image3 = UIImage(named: "6")
        AnimationVideoManager.shared.transacformImages(images: [image, image2, image3, image, image2, image3], animationType: .zoomIn) {[weak self] url in
            print(url.absoluteString)
            self?.playVideo(url: url)
        } failure: { error in
            print(error as Any)
        }
    }
    
    func playVideo(url: URL) {
        DispatchQueue.main.async {
            let avasset = AVURLAsset(url: url)
            let avitem = AVPlayerItem(asset: avasset)
            let player = AVPlayer(playerItem: avitem)
            let pc = AVPlayerViewController()
            pc.player = player
            self.present(pc, animated: true) {
                player.play()
            }
        }
    }
}

