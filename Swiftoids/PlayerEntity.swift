//
//  PlayerEntity.swift
//  Swiftoids
//
//  Created by Richard Lowe on 25/10/2024.
//

import SpriteKit

class PlayerEntity {
    var sprite: SKSpriteNode
    var movementComponent: MovementComponent
    var weaponComponent: WeaponComponent

    init(position: CGPoint) {
        sprite = SKSpriteNode(color: .white, size: CGSize(width: 40, height: 40))
        sprite.position = position
        movementComponent = MovementComponent(node: sprite)
        weaponComponent = WeaponComponent(node: sprite)
    }

    func update(deltaTime: TimeInterval) {
        movementComponent.update(deltaTime: deltaTime)
    }

    func fire() {
        weaponComponent.fire()
    }
}
