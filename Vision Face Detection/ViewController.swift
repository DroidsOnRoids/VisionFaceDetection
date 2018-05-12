//
//  ViewController.swift
//  Vision Face Detection
//
//  Created by Pawel Chmiel on 21.06.2017.
//  Copyright © 2017 Droids On Roids. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

final class ViewController: UIViewController {
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else { return nil }
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sessionPrepare()
        session?.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.frame
        shapeLayer.frame = view.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
        view.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        view.layer.addSublayer(shapeLayer)
    }
    
    func sessionPrepare() {
        session = AVCaptureSession()
        guard let session = session, let captureDevice = frontCamera else { return }
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            print("setup delegate")
        } catch {
            print("can't setup session")
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue))
        
        //detectFace(on: ciImageWithOrientation)
        let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
            if error == nil {
                if let results = request.results as? [VNFaceObservation] {
                    print("Found \(results.count) faces")
                    if results.isEmpty {
                        DispatchQueue.main.async {
                            self.shapeLayer.sublayers?.forEach({ (layer) in
                                layer.removeFromSuperlayer()
                            })
                        }
                    }
                    else {
                        for faceObservation in results {
                            guard let landmarks = faceObservation.landmarks else {
                                continue
                            }
                            DispatchQueue.main.async {
                                self.shapeLayer.sublayers?.forEach({ (layer) in
                                    layer.removeFromSuperlayer()
                                })
                                if let faceContour = landmarks.faceContour {
                                    self.draw(points: faceContour.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let medianLine = landmarks.medianLine {
                                    self.draw(points: medianLine.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let leftEye = landmarks.leftEye {
                                    self.draw(points: leftEye.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let rightEye = landmarks.rightEye {
                                    self.draw(points: rightEye.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let innerLips = landmarks.innerLips {
                                    self.draw(points: innerLips.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let outerLips = landmarks.outerLips {
                                    self.draw(points: outerLips.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let leftEyebrow = landmarks.leftEyebrow {
                                    self.draw(points: leftEyebrow.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let rightEyebrow = landmarks.rightEyebrow {
                                    self.draw(points: rightEyebrow.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let leftPupil = landmarks.leftPupil {
                                    self.draw(points: leftPupil.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let rightPupil = landmarks.rightPupil {
                                    self.draw(points: rightPupil.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let nose = landmarks.nose {
                                    self.draw(points: nose.pointsInImage(imageSize: self.view.frame.size))
                                }
                                if let noseCrest = landmarks.noseCrest {
                                    self.draw(points: noseCrest.pointsInImage(imageSize: self.view.frame.size))
                                }
                            }
                        }
                    }
                }
            } else {
                print(error!.localizedDescription)
            }
        }
        let cgImage = convertCIImageToCGImage(inputImage: ciImageWithOrientation)
        let vnImage = VNImageRequestHandler(cgImage: cgImage!, options: [:])
        try? vnImage.perform([detectFaceRequest])
    }
}

extension ViewController {
    func draw(points: [CGPoint]) {
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = UIColor.red.cgColor
        newLayer.lineWidth = 2.0
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for i in 0..<points.count - 1 {
            let point = CGPoint(x: points[i].x, y: points[i].y)
            path.addLine(to: point)
            path.move(to: point)
        }
        path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))
        newLayer.path = path.cgPath
        shapeLayer.addSublayer(newLayer)
    }
}

func convertCIImageToCGImage(inputImage: CIImage) -> CGImage! {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent)
}
