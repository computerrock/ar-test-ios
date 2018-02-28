//
//  Plane.swift
//  artest
//
//  Created by Ivan Pavlovic on 2/19/18.
//  Copyright © 2018 Ivan Pavlovic. All rights reserved.
//

import UIKit
import ARKit

class Plane: SCNNode {
    
    var anchor: ARPlaneAnchor?
    var planeGeometry: SCNPlane?

    convenience init(anchor: ARPlaneAnchor) {
        self.init()
        self.anchor = anchor
        let pg = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.green.withAlphaComponent(0.5)
        pg.materials = [material]

        self.planeGeometry = pg

        let planeNode = SCNNode(geometry: pg)
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        
        self.setTexture()
        self.addChildNode(planeNode)
    }
    
    func update(anchor: ARPlaneAnchor) {
        self.planeGeometry?.width = CGFloat(anchor.extent.x)
        self.planeGeometry?.height = CGFloat(anchor.extent.z)
        self.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        self.setTexture()
    }
    
    
    func setTexture() {
        guard let pg = self.planeGeometry, let material = pg.materials.first else {
            return
        }
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(pg.width), Float(pg.height), 1)
    }
}

