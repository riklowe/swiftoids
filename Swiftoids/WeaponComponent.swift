//
//  WeaponComponent.swift
//  Swiftoids
//
//  Created by Richard Lowe on 25/10/2024
//

import SpriteKit

// WeaponComponent class for firing projectiles
class WeaponComponent {
    let node: SKSpriteNode

    init(node: SKSpriteNode) {
        self.node = node
    }

    func fire() {
        let projectile = SKSpriteNode(color: .yellow, size: CGSize(width: 10, height: 10))
        projectile.position = node.position
        let projectileDirection = CGVector(dx: cos(node.zRotation) * 500, dy: sin(node.zRotation) * 500)
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.categoryBitMask = GameScene.PhysicsCategory.playerProjectile
        projectile.physicsBody?.contactTestBitMask = GameScene.PhysicsCategory.asteroid
        projectile.physicsBody?.collisionBitMask = 0
        projectile.physicsBody?.velocity = projectileDirection
        projectile.physicsBody?.affectedByGravity = false
        node.scene?.addChild(projectile)
        if let gameScene = node.scene as? GameScene {
            gameScene.projectiles.append(projectile)
        }
    }
}

