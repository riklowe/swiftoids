//
//  MovementComponent.swift
//  Swiftoids
//
//  Created by Richard Lowe on 25/10/2024.
//

import SpriteKit

class MovementComponent {
    let node: SKSpriteNode

    init(node: SKSpriteNode) {
        self.node = node
    }

    func update(deltaTime: TimeInterval) {
        // Update the position of the node based on its velocity
    }

    func rotate(to angle: CGFloat) {
        node.zRotation = angle
    }

    func applyThrust() {
        let dx = cos(node.zRotation) * 50
        let dy = sin(node.zRotation) * 50
        node.physicsBody?.applyImpulse(CGVector(dx: dx, dy: dy))
    }
}
