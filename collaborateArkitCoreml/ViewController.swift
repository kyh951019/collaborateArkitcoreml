//
//  ViewController.swift
//  collaborateArkitCoreml
//
//  Created by 권영호 on 24/01/2019.
//  Copyright © 2019 0ho_kwon. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var sceneController = MainScene()
    
    let currentMLModel = handClassification().model
    private let serialQueue = DispatchQueue(label: "com.aboveground.dispatchqueueml")
    private var visionRequests = [VNRequest]()
    
    private var timer = Timer()
    
    private func setupCoreML() {
        guard let selectedModel = try? VNCoreMLModel(for: currentMLModel) else {
            fatalError("Could not load model.")
        }
        
        let classificationRequest = VNCoreMLRequest(model: selectedModel,
                                                    completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        //Create a new scene
        
        if let scene = sceneController.scene {
            //Set the scene to the view
            sceneView.scene = scene
        }
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.didTapScreen))
        tapRecognizer.numberOfTapsRequired = 1
        tapRecognizer.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(tapRecognizer)

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.delegate = self as? ARSessionDelegate

        // Run the view's session
        sceneView.session.run(configuration)
        
        setupCoreML()
        
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.loopCoreMLUpdate), userInfo: nil, repeats: true)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    @objc
    func didTapScreen(recognizer: UITapGestureRecognizer) {
        if let camera = sceneView.session.currentFrame?.camera {
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -5.0
            let transform = camera.transform * translation
            let position = SCNVector3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            sceneController.addSphere(parent: sceneView.scene.rootNode, position: position)
        }
    }
    
    @objc
    private func loopCoreMLUpdate() {
        serialQueue.async{
            self.updateCoreML()
        }
    }
}
extension ViewController {
    private func updateCoreML() {
//        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        guard let pixbuff: CVPixelBuffer = sceneView.session.currentFrame?.capturedImage else{
            print("pixbuff error")
            return
        }
        
        let deviceOrientation = UIDevice.current.orientation.getImagePropertyOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixbuff, orientation: deviceOrientation,options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }

    private func classificationCompleteHandler(request: VNRequest, error: Error?){
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else{
            return
        }
        
        let classifications = observations[0...2]
            .compactMap({$0 as? VNClassificationObservation})
            .map({"\($0.identifier) \(String(format:" : %.2f", $0.confidence))"})
            .joined(separator: "\n")
        
        print("Classifications: \(classifications)")
        
        DispatchQueue.main.async {
            let topPrediction =  classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            guard let topPredictionScore: Float = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)) else {return}
            
            if (topPredictionScore > 0.95) {
                print("Top prediction: \(topPredictionName) - score: \(String(describing: topPredictionScore))")
                
                guard let childNode = self.sceneView.scene.rootNode.childNode(withName: "Sphere", recursively: true), let sphere = childNode as? Sphere else { print("else")
                    return }
                
                if topPredictionName == "hand_fist" {
                    print("animate")
                    sphere.animate()
                }
                
                if topPredictionName == "hand_open" || topPrediction == "Negative" {
                    print("stop animate")
                    sphere.stopAnimating()
                }
                
            }
        
        }
    }
    
}

extension UIDeviceOrientation {
    func getImagePropertyOrientation() -> CGImagePropertyOrientation {
        switch self {
        case UIDeviceOrientation.portrait, .faceUp: return CGImagePropertyOrientation.right
        case UIDeviceOrientation.portraitUpsideDown, .faceDown: return CGImagePropertyOrientation.left
        case UIDeviceOrientation.landscapeLeft: return CGImagePropertyOrientation.up
        case UIDeviceOrientation.landscapeRight: return CGImagePropertyOrientation.down
        case UIDeviceOrientation.unknown: return CGImagePropertyOrientation.right
        
        }
    }
}
