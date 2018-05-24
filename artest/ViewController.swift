//
//  ViewController.swift
//  artest
//
//  Created by Ivan Pavlovic on 2/10/18.
//  Copyright © 2018 Ivan Pavlovic. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    
    var sceneNode = [SCNNode]()
    
    private var planes = [UUID : Plane]()
    
    lazy var rocketScene: SCNScene? = SCNScene(named: "art.scnassets/Raketa.scn")
    
    var currentObject: SCNNode?
    var currentHitTestResult: ARHitTestResult?

    override func viewDidLoad() {
        super.viewDidLoad()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        self.sceneView.addGestureRecognizer(tap)
        
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        self.sceneView.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.sceneView.addGestureRecognizer(pan)

        
        self.setupScene()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    
    func createSession() {
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        configuration.isLightEstimationEnabled = true
        configuration.detectionImages = referenceImages
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        
        
        self.setupScene()
    }
    
    func startSession() {
        DispatchQueue.main.async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            if status == .authorized {
                self.createSession()
            } else if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted) in
                    if granted {
                        self.createSession()
                    }
                })
            } else {
                
            }
        }
    }
    
    func reloadSession() {
        for scn in self.sceneNode {
            scn.removeFromParentNode()
        }
        self.startSession()
    }
    
    
}

extension ViewController: ARSCNViewDelegate {
    func setupScene() {
        self.sceneView.showsStatistics = true
        self.sceneView.automaticallyUpdatesLighting = true
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            let pln = Plane(anchor: planeAnchor)
            self.planes[planeAnchor.identifier] = pln
            node.addChildNode(pln)
        } else if let imageAnchor = anchor as? ARImageAnchor {
            sceneView.session.setWorldOrigin(relativeTransform: imageAnchor.transform)
            let referenceImage = imageAnchor.referenceImage
            
            if let scene = self.rocketScene {
                let node = scene.rootNode.clone()
                node.scale = SCNVector3(0.001, 0.001, 0.001)
                node.eulerAngles.x = -.pi / 2
                self.sceneNode.append(node)
                self.sceneView.scene.rootNode.addChildNode(node)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, let plane = self.planes[planeAnchor.identifier] else {
            return
        }
        plane.update(anchor: planeAnchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, let index = planes.index(forKey: planeAnchor.identifier) else {
            return
        }
        self.planes.remove(at: index)
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    
    @objc func handlePan(_ pan: UIPinchGestureRecognizer) {
        let point = pan.location(in: self.sceneView)
        let hitResult = self.sceneView.hitTest(point, types: .featurePoint)
        switch pan.state {
        case .began:
            let result = self.sceneView.hitTest(point, options: nil).filter({ (obj) -> Bool in
                for (_, plane) in self.planes {
                    for childNode in plane.childNodes {
                        if obj.node == childNode {
                            return false
                        }
                    }
                }
                return true
            })
            guard result.count > 0, let hr = result.first else {
                return
            }
            self.currentObject = hr.node.parent
            self.currentHitTestResult = hitResult.first
            break
        case .changed:
            guard let obj = self.currentObject, let htr = self.currentHitTestResult, let lastHit = hitResult.last else {
                return
            }
            
            SCNTransaction.begin()
            
            let initMatrix = SCNMatrix4.init(htr.worldTransform)
            let initialVector = SCNVector3(initMatrix.m41, initMatrix.m42, initMatrix.m43)
            
            let matrix = SCNMatrix4.init(lastHit.worldTransform)
            let vector = SCNVector3(matrix.m41, matrix.m42, matrix.m43)
            
            let dx = vector.x - initialVector.x
            let dy = vector.y - initialVector.y
            let dz = vector.z - initialVector.z
            
            obj.position = SCNVector3(obj.position.x + dx, obj.position.y + dy, obj.position.z + dz)
            
            SCNTransaction.commit()
            self.currentHitTestResult = lastHit
            break
        default:
            self.currentObject = nil
        }
    }
    
    @objc func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .began:
            let point = pinch.location(ofTouch: 1, in: self.sceneView)
            let result = self.sceneView.hitTest(point, options: nil).filter({ (obj) -> Bool in
                for (_, plane) in self.planes {
                    for childNode in plane.childNodes {
                        if obj.node == childNode {
                            return false
                        }
                    }
                }
                return true
            })
            guard result.count > 0, let hr = result.first else {
                return
            }
            self.currentObject = hr.node.parent
            break
        case .changed:
            guard let obj = self.currentObject else {
                return
            }
            obj.scale.x = obj.scale.x * Float(pinch.scale)
            obj.scale.y = obj.scale.y * Float(pinch.scale)
            obj.scale.z = obj.scale.z * Float(pinch.scale)
            pinch.scale = 1
            break
        default:
            self.currentObject = nil
        }
    }
    
    @objc func handleTap(_ tap: UITapGestureRecognizer) {
        let point = tap.location(in: self.sceneView)
        let result = self.sceneView.hitTest(point, options: [SCNHitTestOption.boundingBoxOnly : true, SCNHitTestOption.firstFoundOnly: false]).filter({ (obj) -> Bool in
            for (_, plane) in self.planes {
                for childNode in plane.childNodes {
                    if obj.node == childNode {
                        return false
                    }
                }
            }
            return true
        })
        
        if result.count == 0 {
            let planeResult = self.sceneView.hitTest(point, types: .existingPlaneUsingExtent)
            if planeResult.count == 0 {
                return
            }
            if let hitResult = planeResult.first, let scene = self.rocketScene {
                let node = scene.rootNode.clone()
                node.position = SCNVector3(hitResult.worldTransform.columns.3.x, hitResult.worldTransform.columns.3.y, hitResult.worldTransform.columns.3.z)
                node.scale = SCNVector3(0.003, 0.003, 0.003)
                self.sceneNode.append(node)
                self.sceneView.scene.rootNode.addChildNode(node)
            }
        } else if let rocket = result.first?.node {
            if let particle = SCNParticleSystem(named: "Fire.scnp", inDirectory: "art.scnassets/Particles") {
                rocket.addParticleSystem(particle)
                
                let animation = CABasicAnimation(keyPath: "position.y")
                animation.fromValue = 0.0
                animation.toValue = 10000.0
                animation.duration = 10
                animation.autoreverses = false
                animation.repeatCount = 1
                rocket.addAnimation(animation, forKey: "position.y")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 9.0, execute: {
                    rocket.removeFromParentNode()
                })
                
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
