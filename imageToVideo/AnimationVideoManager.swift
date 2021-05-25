//
//  AnimationVideoManager.swift
//  imageToVideo
//
//  Created by admin on 2021/5/18.
//

import UIKit
import AVFoundation

enum AnimationType {
    case fromRightToLeft
    case fromLowerToUpper
    case zoomOut
    case zoomIn
    case rotate
    case fadeInFadeOut
}

class AnimationVideoManager {
        
    static let shared = AnimationVideoManager()
    
    private let outputPath: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("imagesComposition.mp4")
    private let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("baseVideo.mp4")
    private var eachImageDuration: CGFloat = 3
    private var animationDuration: CGFloat = 0.5
    private var alphaAnimationDuration: CGFloat = 0.3
    private var videoWidth: Int = 720
    private var videoHeight: Int = 1280
    private var FPS: Int32 = 30
    private var videoResource: String?
    private var videoDuration: CGFloat = 0
    private var zoomRate: CGFloat = 1.2
    private var animationType: AnimationType = .fromRightToLeft
    private var mouldArray: [AnimationType] = [.zoomIn, .zoomOut, .rotate, .fadeInFadeOut, .fadeInFadeOut, .fadeInFadeOut]
    
    private lazy var videoSetting = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: NSNumber(value: videoWidth), AVVideoHeightKey: NSNumber(value: videoHeight)] as [String : Any]

    func transacformImages(images: [UIImage?], audioUrl: URL? = nil, animationType: AnimationType = .fromRightToLeft, animationDuration: CGFloat = 0.5, alphaAnimationDuration: CGFloat = 0.3, zoomRate: CGFloat = 1.2, FPS: Int32 = 30, videoFrameWidth: Int = 720, videoFrameHeight: Int = 1280, eachImageDuration: CGFloat = 3, success: @escaping (URL) -> Void, failure: @escaping (Error?) -> Void) {
        
        self.animationDuration = animationDuration
        self.FPS = FPS
        self.videoWidth = videoFrameWidth
        self.videoHeight = videoFrameHeight
        self.eachImageDuration = eachImageDuration
        self.animationType = animationType
        self.alphaAnimationDuration = alphaAnimationDuration
        self.zoomRate = zoomRate
        
        removeFileIfExist(url: url)
        removeFileIfExist(url: outputPath)

        do {
            let videoWriter = try AVAssetWriter(outputURL: url, fileType: AVFileType.mov)
            
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSetting)
            
            let zeroTime = CMTimeMake(value: Int64(0),timescale: self.FPS)
            
            videoWriter.canAdd(writerInput)
            videoWriter.add(writerInput)
            
            let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB)]
            let bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: bufferAttributes)
            
            videoWriter.startWriting()
            videoWriter.startSession(atSourceTime: zeroTime)
                        
            let _ = images.enumerated().map { (index, image) in
                while !writerInput.isReadyForMoreMediaData {}
                guard let buffer = newPixelBufferFrom(image: UIImage()) else { return }
                let lastTime = CMTimeMake(value: Int64(index - 1) * Int64(FPS), timescale: self.FPS)
                let presentTime = CMTimeAdd(lastTime, CMTimeMake(value: Int64(FPS), timescale: FPS))
                bufferAdapter.append(buffer, withPresentationTime: index == 0 ? CMTime.zero : presentTime)
            }
            
            writerInput.markAsFinished()
            videoWriter.finishWriting { [weak self] in
                switch videoWriter.status {
                case .completed:
                    self?.videoResource = self?.url.absoluteString
                    self?.imagesVideoAnimation(with: images, audioUrl: audioUrl, success: success, failure: failure)
                default:
                    failure(videoWriter.error)
                }
            }
        }catch {
            failure(error)
        }
        
    }
    
    private func imagesVideoAnimation(with images:[UIImage?], audioUrl: URL? = nil, success: @escaping (URL)->(), failure: @escaping (Error?)->()) {
        guard let videoPath = videoResource, let url = URL(string: videoPath) else {
            failure(NSError.init() as Error)
            return
        }
        
        self.videoDuration = eachImageDuration * CGFloat(images.count)
        let videoAsset = AVURLAsset(url: url)
        let composition = AVMutableComposition()
        let track = videoAsset.tracks(withMediaType: AVMediaType.video)

        guard let assetTrack = track.first else {
            failure(NSError.init() as Error)
            return
        }
        
        let videoTrack:AVAssetTrack = assetTrack as AVAssetTrack
        let endTime = CMTime(value: CMTimeValue(videoAsset.duration.timescale * Int32(videoDuration)), timescale: videoAsset.duration.timescale)
        let timerange = CMTimeRangeMake(start: CMTime.zero, duration: endTime)

        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID())  else {
            failure(NSError.init() as Error)
            return
        }

        do {
            try compositionVideoTrack.insertTimeRange(timerange, of: videoTrack, at: CMTime.zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
        } catch {
            failure(error)
        }

        let size = videoTrack.naturalSize

        let videolayer = CALayer()
        videolayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        let parentlayer = CALayer()
        parentlayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        parentlayer.addSublayer(videolayer)
        
        let imageArray = (animationType == .fromRightToLeft || animationType == .fromLowerToUpper) ? images.enumerated().map { (ele) -> EnumeratedSequence<[UIImage?]>.Element in
            return ele
        } : images.enumerated().reversed()
        
        for (index, image) in imageArray {

            let nextImage = image

            let horizontalRatio = CGFloat(self.videoWidth) / (nextImage?.size.width ?? 0)
            let verticalRatio = CGFloat(self.videoHeight) / (nextImage?.size.height ?? 0)
            let aspectRatio = min(horizontalRatio, verticalRatio)
            let newSize: CGSize = CGSize(width: (nextImage?.size.width ?? 0) * aspectRatio, height: (nextImage?.size.height ?? 0) * aspectRatio)
            let x = newSize.width < CGFloat(self.videoWidth) ? (CGFloat(self.videoWidth) - newSize.width) / 2 : 0
            let y = newSize.height < CGFloat(self.videoHeight) ? (CGFloat(self.videoHeight) - newSize.height) / 2 : 0

            let blackLayer = CALayer()
            blackLayer.frame = CGRect(x: 0, y: 0, width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)
            blackLayer.backgroundColor = UIColor.black.cgColor
            
            let imageLayer = CALayer()
            imageLayer.backgroundColor = UIColor.black.cgColor
            imageLayer.frame = CGRect(x: x, y: y, width: newSize.width, height: newSize.height)
            imageLayer.contents = image?.cgImage
            blackLayer.addSublayer(imageLayer)
            
            positionAnimation(layer: blackLayer, index: index, isLastOne: index == images.count - 1)

            parentlayer.addSublayer(blackLayer)
        }

        let layercomposition = AVMutableVideoComposition()
        layercomposition.frameDuration = CMTimeMake(value: 1, timescale: self.FPS)
        layercomposition.renderSize = size
        layercomposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videolayer, in: parentlayer)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: composition.duration)
        let videotrack = composition.tracks(withMediaType: AVMediaType.video)[0] as AVAssetTrack
        let layerinstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videotrack)
        instruction.layerInstructions = [layerinstruction]
        layercomposition.instructions = [instruction]

        guard let assetExport = AVAssetExportSession(asset: composition, presetName:AVAssetExportPresetHighestQuality) else {return}
        assetExport.videoComposition = layercomposition
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = outputPath
        assetExport.audioMix = audioMix(audioUrl: audioUrl, composition: composition, timerange: timerange)
        assetExport.exportAsynchronously(completionHandler: { [weak self] in
            guard let weakSelf = self else {
                failure(NSError.init() as Error)
                return
            }
            switch assetExport.status{
            case AVAssetExportSession.Status.completed:
                success(weakSelf.outputPath)
            default:
                failure(assetExport.error)
            }
        })
    }
    
    private func audioMix(audioUrl: URL?, composition: AVMutableComposition, timerange: CMTimeRange) -> AVAudioMix? {
        guard let url = audioUrl else { return nil }
        let audioAsset = AVURLAsset(url: url)
        let audioDuration = Int(audioAsset.duration.value) / Int(audioAsset.duration.timescale)
        let loopCount = Int(videoDuration) / audioDuration
        let residue = Int(videoDuration) - (audioDuration * loopCount)
        var musicDuration = CMTime.zero
        let audioTrack = audioAsset.tracks(withMediaType: AVMediaType.audio)
        guard let audioAssetTrack = audioTrack.first else { return nil }
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())
        
        let audioMix: AVMutableAudioMix = AVMutableAudioMix()
        var audioMixParam: [AVMutableAudioMixInputParameters] = []
        let audioParam: AVMutableAudioMixInputParameters = AVMutableAudioMixInputParameters(track: audioAssetTrack)
        audioParam.trackID = compositionAudioTrack?.trackID ?? CMPersistentTrackID()
        audioParam.setVolume(1, at: .zero)
        audioMixParam.append(audioParam)
        audioMix.inputParameters = audioMixParam
        
        do{
            for _ in 0..<loopCount {
                try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: audioAsset.duration), of: audioAssetTrack, at: musicDuration)
                musicDuration = CMTimeAdd(musicDuration, audioAsset.duration)
            }
            if residue > 0 {
                let dura = CMTime(value: CMTimeValue(residue), timescale: 1)
                try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: dura), of: audioAssetTrack, at: musicDuration)
            }
        }catch {
            return nil
        }
        
        return audioMix
    }
    
    private func positionAnimation(layer: CALayer, index: Int, isLastOne: Bool) {
        self.animationType = mouldArray[index]
        switch self.animationType {
        case .fromRightToLeft:
            if index == 0 { return }
            layer.frame = CGRect(x: Int(Double(videoWidth) * 1.5), y: 0, width: videoWidth, height: videoHeight)
            let animation = CABasicAnimation(keyPath: "position.x")
            animation.fromValue = Double(videoWidth) * 1.5
            animation.toValue = videoWidth / 2
            animation.duration = CFTimeInterval(animationDuration)
            animation.beginTime = CFTimeInterval(eachImageDuration * CGFloat(index) - animationDuration / 2)
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
            layer.add(animation, forKey: "position.x")
                
        case .fromLowerToUpper:
            if index == 0 { return }
            layer.frame = CGRect(x: 0, y: -(videoHeight * Int(1.5)), width: videoWidth, height: videoHeight)
            let animation = CABasicAnimation(keyPath: "position.y")
            animation.fromValue = -(Double(videoHeight) * 1.5)
            animation.toValue = videoHeight / 2
            animation.duration = CFTimeInterval(animationDuration)
            animation.beginTime = CFTimeInterval(eachImageDuration * CGFloat(index) - animationDuration / 2)
            animation.isRemovedOnCompletion = false
            animation.fillMode = .forwards
            layer.add(animation, forKey: "position.y")

        case .zoomIn:
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = zoomRate
            scaleAnimation.toValue = 1
            scaleAnimation.beginTime = index == 0 ? -0.001 : CFTimeInterval(animationDuration + eachImageDuration * CGFloat(index) - alphaAnimationDuration)
            scaleAnimation.duration = CFTimeInterval(eachImageDuration)
            scaleAnimation.isRemovedOnCompletion = false
            layer.add(scaleAnimation, forKey: "transform.scale")
                
            let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
            fadeOutAnimation.fromValue = 1
            fadeOutAnimation.toValue = 0
            fadeOutAnimation.duration = CFTimeInterval(alphaAnimationDuration)
            fadeOutAnimation.beginTime = CFTimeInterval(animationDuration + eachImageDuration * CGFloat(index) + (eachImageDuration - alphaAnimationDuration))
            fadeOutAnimation.isRemovedOnCompletion = false
            fadeOutAnimation.fillMode = .forwards
            layer.add(fadeOutAnimation, forKey: "opacity")
                
        case .zoomOut:
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1
            scaleAnimation.toValue = zoomRate
            scaleAnimation.beginTime = CFTimeInterval(animationDuration + eachImageDuration * CGFloat(index))
            scaleAnimation.duration = CFTimeInterval(eachImageDuration)
            scaleAnimation.isRemovedOnCompletion = false
            layer.add(scaleAnimation, forKey: "transform.scale")
                
            let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
            fadeOutAnimation.fromValue = 1
            fadeOutAnimation.toValue = 0
            fadeOutAnimation.duration = CFTimeInterval(alphaAnimationDuration)
            fadeOutAnimation.beginTime = CFTimeInterval(animationDuration + eachImageDuration * CGFloat(index) + (eachImageDuration - alphaAnimationDuration))
            fadeOutAnimation.isRemovedOnCompletion = false
            fadeOutAnimation.fillMode = .forwards
            layer.add(fadeOutAnimation, forKey: "opacity")
            
        case .rotate:
            let animationDurationMargin = isLastOne ? 0 : animationDuration / 2
            let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
            scaleAnimation.fromValue = 1
            scaleAnimation.toValue = 0
            scaleAnimation.beginTime = CFTimeInterval(eachImageDuration * CGFloat(index + 1) - animationDurationMargin)
            scaleAnimation.duration = CFTimeInterval(animationDuration)
            scaleAnimation.isRemovedOnCompletion = false
            scaleAnimation.fillMode = .forwards
            layer.add(scaleAnimation, forKey: "transform.scale")
            
            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = 2 * Double.pi
            rotation.duration = CFTimeInterval(animationDuration)
            rotation.beginTime = CFTimeInterval(eachImageDuration * CGFloat(index + 1) - animationDurationMargin)
            rotation.isRemovedOnCompletion = false
            rotation.fillMode = .forwards
            layer.add(rotation, forKey: "transform.rotation.z")
            
        case .fadeInFadeOut:
            let animationDurationMargin = isLastOne ? 0 : animationDuration / 2
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 1
            opacity.toValue = 0
            opacity.beginTime = CFTimeInterval(eachImageDuration * CGFloat(index + 1) - animationDurationMargin)
            opacity.duration = CFTimeInterval(animationDuration)
            opacity.isRemovedOnCompletion = false
            opacity.fillMode = .forwards
            layer.add(opacity, forKey: "opacity")

        }
    }
}

extension AnimationVideoManager {
    
    private func removeFileIfExist(url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            }catch {
                print(error)
            }
        }
    }
    
    private func newPixelBufferFrom(image: UIImage) -> CVPixelBuffer? {
        
        let options:[String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        
        var pxbuffer:CVPixelBuffer? = nil
        
        guard let frameWidth = self.videoSetting[AVVideoWidthKey] as? Int, let frameHeight: Int = self.videoSetting[AVVideoHeightKey] as? Int else { return nil }
        
        let _ = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxbuffer)
                
        guard let newPxbuffer = pxbuffer else { return nil }

        CVPixelBufferLockBaseAddress(newPxbuffer, CVPixelBufferLockFlags(rawValue: 0))

        let pxdata = CVPixelBufferGetBaseAddress(newPxbuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pxdata, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(newPxbuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }

        UIGraphicsPushContext(context)
        context.translateBy(x: 0, y: CGFloat(frameHeight))
        context.scaleBy(x: 1, y: -1)
        image.draw(in: CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight))
        UIGraphicsPopContext()
        
        CVPixelBufferUnlockBaseAddress(newPxbuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pxbuffer
    }
}
