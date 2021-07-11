//
//  AppDelegate.swift
//  GrayScale Swift
//
//  Created by Harshil Patel on 11/04/21.
//

import Cocoa
import AVFoundation
import Photos

@main
class AppDelegate: NSObject, NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
    
    
    var outputSize = CGSize(width: 1920  , height: 1280)
    var imagesPerSecond: TimeInterval = 1
    var fps: Int32 = 30
    var selectedPhotosArray = [NSImage]()
    var imageArrayToVideoURL = NSURL()
    var asset: AVAsset!
    var imageCount = 1
    var concurrentQueue = DispatchQueue(label: "recordingQueue", attributes: .concurrent)
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        var originalVideo = AVAsset(url: outputFileURL)
        
        let item = AVPlayerItem(asset: originalVideo)
        buildVideoFromImageArray()
        
        print("Done")
    }
    
    var tempInt = 0
    

    func documentsPathForFileName(name: String) -> String {
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            return documentsPath.appending(name)
        }
    
    
    @IBOutlet weak var btnRecord: NSButton!
    @IBOutlet var window: NSWindow!
    @IBOutlet weak var previewView: NSView!
    @IBOutlet weak var tempImage: NSImageView!
    
    @IBOutlet weak var tempImgView1: NSImageView!
    @IBOutlet weak var tempImgView3: NSImageView!
    @IBOutlet weak var tempImgView4: NSImageView!
    @IBOutlet weak var tempImgView5: NSImageView!
    @IBOutlet weak var tempImgView6: NSImageView!
    
    
    
    var captureSession: AVCaptureSession? = nil
    var captureDevice: AVCaptureDevice? = nil
    var previewlayer: AVCaptureVideoPreviewLayer? = nil
    var outputFile: AVCaptureMovieFileOutput? = nil
    var isWriting = false
    var currentSampleTime: CMTime?
    var assetWriter: AVAssetWriter?
       var currentVideoDimensions: CMVideoDimensions?
    var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor?
    var assetWriterVideoInput: AVAssetWriterInput?
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        captureSession = AVCaptureSession()
        outputFile = AVCaptureMovieFileOutput()

        btnRecord.title = "Start Record"

        previewView.layer = CALayer()
        captureSession?.sessionPreset = .iFrame1280x720 //AVCaptureSessionPreset1280x720, AVCaptureSessionPreset320x240 AVCaptureSessionPresetLow
        captureSession?.addOutput(outputFile!)
        
        captureDevice = AVCaptureDevice.default(for: .video)

        if captureDevice != nil {

            do {
                try captureSession!.addInput(AVCaptureDeviceInput(device: captureDevice!))
            } catch {
            }
            previewlayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewlayer!.frame = previewView.frame
            previewlayer?.connection?.automaticallyAdjustsVideoMirroring = false
            previewlayer?.connection?.isVideoMirrored = true
            //You can use Any of this filters for the view
//            CIPhotoEffectMono,CIColorInvert,CIColorMonochrome,CIColorPosterize, CIFalseColor, CIMaskToAlpha, CIMinimumComponent, CIMinimumComponent, CIPhotoEffectChrome, CIPhotoEffectFade, CIPhotoEffectInstant, CIPhotoEffectProcess, CIPhotoEffectTransfer, CIPhotoEffectTonal, CISepiaTone, CIVignetteEffect, CIVignetteEffect
            
//            let filter = CIFilter(name: "CIPhotoEffectMono")
//            previewlayer?.filters = [filter as Any]
            previewlayer?.videoGravity = .resize
//            filter.setValue(cameraImage, forKey: kCIInputImageKey)
            //        [_previewlayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            previewView.layer?.addSublayer(previewlayer!)
            captureSession?.startRunning()
        }
        previewView.layer?.layoutManager = CAConstraintLayoutManager()
        
        let videoOut = AVCaptureVideoDataOutput()

        let pixelFormatCode = NSNumber(value: UInt32(UInt(kCVPixelFormatType_32BGRA)))
        let pixelFormatKey = kCVPixelBufferPixelFormatTypeKey as String
        let videoSettings = [
            pixelFormatKey : pixelFormatCode
        ]
        
        concurrentQueue = DispatchQueue(label: "recordingQueue", attributes: .concurrent)
        videoOut.setSampleBufferDelegate(self, queue: concurrentQueue)
        videoOut.videoSettings = videoSettings
        
        if captureSession!.canAddOutput(videoOut) {
            captureSession!.addOutput(videoOut)
        }
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func btnRecordAction(_ sender: NSButton) {
        
        if (sender.title == "Start Record") {
            isWriting = true
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: currentSampleTime!)
            
            createWriter()
            var homeDriPath = FileManager.default.homeDirectoryForCurrentUser
            homeDriPath = homeDriPath.appendingPathComponent("Desktop")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let currentDate = Date()
            let dateString = formatter.string(from: currentDate)
            formatter.dateFormat = "HH.mm.ss a"
            let timeString = formatter.string(from: currentDate)
            let fileName = "Capture \(dateString) at \(timeString)"
            let outPutPath = "\(homeDriPath.path)/\(fileName).mp4"
            outputFile?.startRecording(to: URL(fileURLWithPath: outPutPath), recordingDelegate: self)
            btnRecord.title = "Stop Record"
        } else {
            isWriting = false
            btnRecord.title = "Start Record"
            outputFile?.stopRecording()
        }
    }
    
    func movieURL() -> NSURL {
            let tempDir = NSTemporaryDirectory()
            let url = NSURL(fileURLWithPath: tempDir).appendingPathComponent("tmpMov.mov")
            return url! as NSURL
        }
    
    func createWriter() {
        do {
            assetWriter = try AVAssetWriter(outputURL: movieURL() as URL, fileType: AVFileType.mov)
        } catch let error as NSError {
            print(error.localizedDescription)
            return
        }
        
        let outputSettings = [
            AVVideoCodecKey : AVVideoCodecH264,
            AVVideoWidthKey : currentVideoDimensions?.width ,
            AVVideoHeightKey : currentVideoDimensions?.height
        ] as [String : Any]
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings as? [String : AnyObject])
        assetWriterVideoInput!.expectsMediaDataInRealTime = true
        assetWriterVideoInput!.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI / 2.0))
        
        let sourcePixelBufferAttributesDictionary = [
            String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_64ARGB),
            String(kCVPixelBufferWidthKey) : currentVideoDimensions?.width,
            String(kCVPixelBufferHeightKey) : currentVideoDimensions?.height,
        ] as [String : Any]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        
        if assetWriter!.canAdd(assetWriterVideoInput!) {
            assetWriter!.add(assetWriterVideoInput!)
        } else {
            print("no way\(assetWriterVideoInput)")
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool {
            
            
            var videoRecorder: AVAssetWriter?
            
            let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            //            if videoRecorder?.status == .unknown {
            //                startRecordingTime = timeStamp
            videoRecorder?.startWriting()
            videoRecorder?.startSession(atSourceTime: timeStamp)
            //            }
            
            
            connection.videoOrientation = .landscapeLeft;
            
            guard let pixelBuffer11 = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let cameraImage = CIImage(cvPixelBuffer: pixelBuffer11)
            
            let filter = CIFilter(name: "CIPhotoEffectNoir")!
            filter.setValue(cameraImage, forKey: kCIInputImageKey)
            
            
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
            CMVideoFormatDescriptionGetDimensions(formatDescription)
            currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            
//            if self.isWriting {
                autoreleasepool {
                    if self.assetWriterPixelBufferInput?.assetWriterInput.isReadyForMoreMediaData == true {
                        // COMMENT: Here's where it gets weird. You've declared a new, empty pixelBuffer... but you already have one (pixelBuffer) that contains the image you want to write...
                        if (self.assetWriterPixelBufferInput!.pixelBufferPool != nil) {
                            var newPixelBuffer: CVPixelBuffer? = nil
                            
                            // COMMENT: And you grabbed memory from the pool.
                            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, self.assetWriterPixelBufferInput!.pixelBufferPool!, &newPixelBuffer)
                            
                            // COMMENT: And now you wrote an empty pixelBuffer back <-- this is what's causing the black frame.
                            let success = self.assetWriterPixelBufferInput?.append(newPixelBuffer!, withPresentationTime: currentSampleTime!)
                            
                            if success == false {
                                print("Pixel Buffer failed")
                            }
                        }
                    }
//                }
                
                DispatchQueue.main.async {
                    self.setupVideoToAllViews(cameraImage)
//                    if let outputValue = filter.value(forKey: kCIOutputImageKey) as? CIImage {
//                        let rep = NSCIImageRep(ciImage: outputValue)
//                        let filteredImage = NSImage(size: rep.size)
//                        filteredImage.addRepresentation(rep)
//                        self.selectedPhotosArray.append(filteredImage)
//                        self.tempImage.image = filteredImage
//                    }
                }
            }
        }
    }
    
    func setupVideoToAllViews(_ image:CIImage) {
        //You can use Any of this filters for the view
        
        //            CIPhotoEffectMono,CIColorInvert,CIColorMonochrome,CIColorPosterize, CIFalseColor, CIMaskToAlpha, CIMinimumComponent, CIMinimumComponent, CIPhotoEffectChrome, CIPhotoEffectFade, CIPhotoEffectInstant, CIPhotoEffectProcess, CIPhotoEffectTransfer, CIPhotoEffectTonal, CISepiaTone, CIVignetteEffect, CIVignetteEffect
        
        ///CIPhotoEffectNoir
        
        self.tempImgView1.image = applyFilter(name: "CIPhotoEffectMono", image: image)
        self.tempImage.image = applyFilter(name: "CIPhotoEffectTransfer", image: image)
        self.tempImgView3.image = applyFilter(name: "CIColorPosterize", image: image)
        self.tempImgView4.image = applyFilter(name: "CIFalseColor", image: image)
        self.tempImgView5.image = applyFilter(name: "CIPhotoEffectChrome", image: image)
        self.tempImgView6.image = applyFilter(name: "CISepiaTone", image: image)
        let singleImage = self.applyFilter(name: "CIPhotoEffectMono", image: image)
        tempInt+=1
//        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
//        let destinationURL = desktopURL.appendingPathComponent("my\(tempInt)-image.png")
//                if singleImage.pngWrite(to: destinationURL, options: .withoutOverwriting) {
//                    print("File saved")
//                    do {
//                        let workspace = NSWorkspace.shared
//                        if let screen = NSScreen.main  {
//                            try workspace.setDesktopImageURL(destinationURL, for: screen, options: [:])
//                        }
//                    } catch {
//                        print(error)
//                    }
//                }
    }
    
    func applyFilter(name: String, image:CIImage) -> NSImage {
        let filter = CIFilter(name: name)!
        filter.setValue(image, forKey: kCIInputImageKey)
        if let outputValue = filter.value(forKey: kCIOutputImageKey) as? CIImage {
            
            let rep = NSCIImageRep(ciImage: outputValue)
            let filteredImage = NSImage(size: rep.size)
            filteredImage.addRepresentation(rep)
            self.selectedPhotosArray.append(filteredImage)
            return filteredImage
        }
        return NSImage()
    }
    
    
    func buildVideoFromImageArray() {
        
        var homeDriPath = FileManager.default.homeDirectoryForCurrentUser
        homeDriPath = homeDriPath.appendingPathComponent("Desktop")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let currentDate = Date()
        let dateString = formatter.string(from: currentDate)
        formatter.dateFormat = "HH.mm.ss a"
        let timeString = formatter.string(from: currentDate)
        let fileName = "Gray \(dateString) at \(timeString)"
        let outPutPath = "\(homeDriPath.path)/\(fileName).mp4"
        
        imageArrayToVideoURL = NSURL(fileURLWithPath: outPutPath)
        removeFileAtURLIfExists(url: imageArrayToVideoURL)
        guard let videoWriter = try? AVAssetWriter(outputURL: imageArrayToVideoURL as URL, fileType: AVFileType.mp4) else {
            fatalError("AVAssetWriter error")
        }
        let outputSettings = [AVVideoCodecKey : AVVideoCodecType.h264, AVVideoWidthKey : NSNumber(value: Float(outputSize.width)), AVVideoHeightKey : NSNumber(value: Float(outputSize.height))] as [String : Any]
        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            fatalError("Negative : Can't applay the Output settings...")
        }
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB), kCVPixelBufferWidthKey as String: NSNumber(value: Float(outputSize.width)), kCVPixelBufferHeightKey as String: NSNumber(value: Float(outputSize.height))]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        if videoWriter.startWriting() {
            let zeroTime = CMTimeMake(value: Int64(imagesPerSecond),timescale: self.fps)
            videoWriter.startSession(atSourceTime: zeroTime)
            
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
            
            videoWriterInput.requestMediaDataWhenReady(on: concurrentQueue, using: { () -> Void in
                //let fps: Int32 = 1
                let framePerSecond: Int64 = Int64(self.imagesPerSecond)
                let frameDuration = CMTimeMake(value: Int64(self.imagesPerSecond), timescale: self.fps)
                var frameCount: Int64 = 0
                var appendSucceeded = true
                while (!self.selectedPhotosArray.isEmpty) {         // wird so lange ausgeführt, bis noch etwas im Array steht
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        let nextPhoto = self.selectedPhotosArray.remove(at: 0)  // foto wird aus dem selectedPhotosArray gelöscht
                        
                        let lastFrameTime = CMTimeMake(value: frameCount * framePerSecond, timescale: self.fps)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                        if let pixelBuffer = pixelBuffer, status == 0 {
                            let managedPixelBuffer = pixelBuffer
                            CVPixelBufferLockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            let context = CGContext(data: data, width: Int(self.outputSize.width), height: Int(self.outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                            context!.clear(CGRect(x: 0, y: 0, width: CGFloat(self.outputSize.width), height: CGFloat(self.outputSize.height)))
                            let horizontalRatio = CGFloat(self.outputSize.width) / nextPhoto.size.width
                            let verticalRatio = CGFloat(self.outputSize.height) / nextPhoto.size.height
                            //let aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
                            
                            let newSize: CGSize = CGSize(width: nextPhoto.size.width * aspectRatio, height: nextPhoto.size.height * aspectRatio)
                            
                            let x = newSize.width < self.outputSize.width ? (self.outputSize.width - newSize.width) / 2 : 0
                            let y = newSize.height < self.outputSize.height ? (self.outputSize.height - newSize.height) / 2 : 0
                            
                            context?.draw(nextPhoto.CGImage, in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                            appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                    }
                    if !appendSucceeded {
                        break
                    }
                    frameCount += 1
                }
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting { () -> Void in
                    print("-----video1 url = \(self.imageArrayToVideoURL)")
                    
                    //self.asset = AVAsset(url: self.imageArrayToVideoURL as URL)
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.imageArrayToVideoURL as URL)
                    }) { saved, error in
                        if saved {
                            let fetchOptions = PHFetchOptions()
                            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                            
                            _ = PHAsset.fetchAssets(with: .video, options: fetchOptions).firstObject
                            // fetchResult is your latest video PHAsset
                            // To fetch latest image  replace .video with .image
                        }
                    }
                }
            })
        }
    }
    
    func removeFileAtURLIfExists(url: NSURL) {
        if let filePath = url.path {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                do{
                    try fileManager.removeItem(atPath: filePath)
                } catch let error as NSError {
                    print("Couldn't remove existing destination file: \(error)")
                }
            }
        }
    }
}

extension NSImage {
    var CGImage: CGImage {
        get {
            let imageData = self.tiffRepresentation!
            let source = CGImageSourceCreateWithData(imageData as CFData, nil).unsafelyUnwrapped
            let maskRef = CGImageSourceCreateImageAtIndex(source, Int(0), nil)
            return maskRef.unsafelyUnwrapped
        }
    }
    var pngData: Data? {
            guard let tiffRepresentation = tiffRepresentation, let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
            return bitmapImage.representation(using: .png, properties: [:])
        }
        func pngWrite(to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
            do {
                try pngData?.write(to: url, options: options)
                return true
            } catch {
                print(error)
                return false
            }
        }
}
