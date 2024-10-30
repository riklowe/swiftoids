//  GameScene.swift
//  Swiftoids
//
//  Created by Richard Lowe on 25/10/2024.
//
import SpriteKit
import GameplayKit
import AVFoundation

enum AsteroidSize {
    case small, medium, large
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    // Track if level is complete to prevent multiple calls
    var isLevelComplete = false
    var level = 1 // Added level tracking

    // Player's spaceship
    var player: SKSpriteNode!

    // Array to hold asteroids
    var asteroids: [SKSpriteNode] = []

    // Array to hold projectiles
    var projectiles: [SKSpriteNode] = []
    var saucerProjectiles: [SKSpriteNode] = []
    var projectileLifetimes: [SKSpriteNode: TimeInterval] = [:]

    var lastUpdateTime: TimeInterval = 0

    // Player's lives
    var lives = 0  {
        didSet {
            livesLabel.text = "Lives: \(lives)"
        }
    }

    var score = 0
    {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }

    var scoreLabel: SKLabelNode!
    var livesLabel: SKLabelNode!

    var instructionsLabel: SKLabelNode!
    var tapToStartLabel: SKLabelNode!
    var isGameStarted: Bool = false
    var levelCompleteLabel: SKLabelNode!
    var asteroidsLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!

    var gameOverLabel: SKLabelNode!
    var restartLabel: SKLabelNode!

    let shootSound = SKAction.playSoundFileNamed("fire", waitForCompletion: false)
    let thrustSound = SKAction.playSoundFileNamed("thrust", waitForCompletion: false)
    let bangLSound = SKAction.playSoundFileNamed("bangLarge", waitForCompletion: false)
    let bangMSound = SKAction.playSoundFileNamed("bangMedium", waitForCompletion: false)
    let bangSSound = SKAction.playSoundFileNamed("bangSmall", waitForCompletion: false)
    let saucerBSound = SKAction.playSoundFileNamed("saucerBig", waitForCompletion: false)

    var thrustAudioPlayer: AVAudioPlayer?
    var saucerAudioPlayer: AVAudioPlayer?
    var smallSaucerAudioPlayer: AVAudioPlayer?

    var highScore = UserDefaults.standard.integer(forKey: "highScore")

    // Physics categories
    struct PhysicsCategory {
        static let player: UInt32 = 0x1 << 0
        static let asteroid: UInt32 = 0x1 << 1
        static let playerProjectile: UInt32 = 0x1 << 2
        static let saucer: UInt32 = 0x1 << 3
        static let saucerProjectile: UInt32 = 0x1 << 4
    }

    // Flying saucer node
    var saucer: SKSpriteNode?
    var smallSaucer: SKSpriteNode?

    //MARK: - Player
    // Setup player's spaceship
    func setupPlayer() {
        print (#function)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 14)) // Reduced size by 30%
        path.addLine(to: CGPoint(x: -7, y: -7)) // Reduced size by 30%
        path.addLine(to: CGPoint(x: 7, y: -7)) // Reduced size by 30%
        path.closeSubpath()

        player = SKSpriteNode()
        let shape = SKShapeNode(path: path)
        shape.fillColor = .black
        shape.strokeColor = .white
        shape.name = "spaceshipShape"
        shape.lineWidth = 2
        player.addChild(shape)
        player.position = CGPoint(x: frame.midX, y: frame.midY)
        player.physicsBody = SKPhysicsBody(polygonFrom: path)
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.asteroid | PhysicsCategory.saucerProjectile
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = false
        addChild(player)
    }

    // Setup thrust animation
    func setupThrustAnimation() {
        print (#function)

        let thrustPath = CGMutablePath()
        thrustPath.move(to: CGPoint(x: 0, y: -14)) // Reduced size by 30%
        thrustPath.addLine(to: CGPoint(x: -5, y: 0)) // Reduced size by 30%
        thrustPath.addLine(to: CGPoint(x: 5, y: 0)) // Reduced size by 30%
        thrustPath.closeSubpath()

        let thrustNode = SKShapeNode(path: thrustPath)
        thrustNode.fillColor = .black
        thrustNode.strokeColor = .white
        thrustNode.lineWidth = 2
        thrustNode.isHidden = true
        thrustNode.name = "thrustNode"
        thrustNode.position = CGPoint(x: 0, y: -7)  // Position the triangle right at the back of the spaceship, adjusted for new size
        player.addChild(thrustNode)
    }

    // Apply thrust to the player's spaceship
    func applyThrust() {
        print(#function)

        if thrustAudioPlayer == nil || thrustAudioPlayer?.isPlaying == false {
            if let soundURL = Bundle.main.url(forResource: "thrust", withExtension: "wav") {
                do {
                    thrustAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    thrustAudioPlayer?.numberOfLoops = -1 // Infinite loop
                    thrustAudioPlayer?.play()
                    print("play thrust")
                } catch {
                    print("Error: Could not load or play thrust sound.")
                }
            }
        }

        addThrustAnimation()
        let thrustAmount: CGFloat = 5.0 // Reduced thrust acceleration by 50%
        let dx = cos(player.zRotation + .pi / 2) * thrustAmount
        let dy = sin(player.zRotation + .pi / 2) * thrustAmount
        player.physicsBody?.applyForce(CGVector(dx: dx, dy: dy))
    }


    // Show thrust animation
    func addThrustAnimation() {
        print (#function)
        if let thrustNode = player.childNode(withName: "thrustNode") as? SKShapeNode {
            thrustNode.isHidden = false
        }
    }

    // Hide thrust animation
    func removeThrustAnimation() {
        print(#function)
        if let thrustNode = player.childNode(withName: "thrustNode") as? SKShapeNode {
            thrustNode.isHidden = true
        }
        if thrustAudioPlayer?.isPlaying == true {
            thrustAudioPlayer?.stop()
            thrustAudioPlayer = nil
        }
    }

    // Fire projectile from the player's spaceship
    func fireProjectile(currentTime: TimeInterval) {
        run(shootSound)

        let projectile = SKSpriteNode(color: .yellow, size: CGSize(width: 5, height: 5))

        // Adjust the projectile to start from the exact tip of the triangle
        let tipOffset: CGFloat = 20.0 // Distance from the player's center to the tip of the triangle
        let rotation = player.zRotation
        let dx = cos(rotation + .pi / 2)
        let dy = sin(rotation + .pi / 2)
        let tipX = player.position.x + dx * tipOffset
        let tipY = player.position.y + dy * tipOffset
        projectile.position = CGPoint(x: tipX, y: tipY)
        projectile.zRotation = player.zRotation
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectile.size)
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.playerProjectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.asteroid | PhysicsCategory.saucer
        projectile.physicsBody?.collisionBitMask = 0
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.linearDamping = 0
        projectile.physicsBody?.angularDamping = 0
        projectile.physicsBody?.allowsRotation = false

        let projectileSpeed: CGFloat = 1000.0
        projectile.physicsBody?.velocity = CGVector(dx: dx * projectileSpeed, dy: dy * projectileSpeed)
        addChild(projectile)
        projectiles.append(projectile)

        // Track projectile lifetime
        projectileLifetimes[projectile] = currentTime
    }


    func handleProjectileLifetime(for projectile: SKSpriteNode) {
        // You may increase the threshold to avoid prematurely removing projectiles that could wrap
        print (#function)
        let outOfBoundsThreshold: CGFloat = 1.0

        if projectile.position.x > frame.maxX + outOfBoundsThreshold || projectile.position.x < frame.minX - outOfBoundsThreshold ||
            projectile.position.y > frame.maxY + outOfBoundsThreshold || projectile.position.y < frame.minY - outOfBoundsThreshold {
            projectile.removeFromParent()
            projectiles.removeAll { $0 == projectile }
        }

    }

    func handleProjectileWrapAround(for projectile: SKSpriteNode) {
        // Wrap around horizontally
        if projectile.position.x > frame.maxX {
            projectile.position.x = frame.minX
        } else if projectile.position.x < frame.minX {
            projectile.position.x = frame.maxX
        }

        // Wrap around vertically
        if projectile.position.y > frame.maxY {
            projectile.position.y = frame.minY
        } else if projectile.position.y < frame.minY {
            projectile.position.y = frame.maxY
        }

        // Avoid hitting the player
        if projectile.frame.intersects(player.frame) {
            projectile.removeFromParent()
            projectiles.removeAll { $0 == projectile }
            projectileLifetimes.removeValue(forKey: projectile)
        }
    }



    // Player hit by asteroid or saucer bullet
    func playerHit(by node: SKSpriteNode) {

        node.removeFromParent()

        if node.physicsBody?.categoryBitMask == PhysicsCategory.asteroid {
            asteroids.removeAll { $0 == node }
        } else if node.physicsBody?.categoryBitMask == PhysicsCategory.saucerProjectile {
            projectiles.removeAll { $0 == node }
        }

        if let shape = player.childNode(withName: "spaceshipShape") as? SKShapeNode {
            shape.fillColor = SKColor.red
            let fadeAction = SKAction.sequence([
                SKAction.wait(forDuration: 0.5),
                SKAction.run { shape.fillColor = .black }
            ])
            shape.run(fadeAction)
        }

        lives -= 1

        if lives <= 0 {
            gameOver()
        }
    }

    func repositionPlayer() {
        player.removeAllActions()
        player.physicsBody?.velocity = .zero
        player.physicsBody?.angularVelocity = 0
        player.position = CGPoint(x: frame.midX, y: frame.midY)
        player.zRotation = 0
        removeThrustAnimation()
    }

    //MARK: - Saucer
    // Setup flying saucer
    func setupSaucer() {
        print (#function)

        //saucerSoundAction = SKAction.playSoundFileNamed("saucerBig.wav", waitForCompletion: true)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -15, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -10))
        path.addLine(to: CGPoint(x: 15, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 10))
        path.closeSubpath()

        saucer = SKSpriteNode()
        let base = SKShapeNode(path: path)
        base.fillColor = .black
        base.strokeColor = .white
        base.lineWidth = 2
        saucer?.addChild(base)

        // Create a semicircle dome for the top of the saucer
        let domePath = CGMutablePath()
        domePath.addArc(center: CGPoint(x: 0, y: 5), radius: 5, startAngle: 0, endAngle: .pi, clockwise: false)
        let dome = SKShapeNode(path: domePath)
        dome.fillColor = .black
        dome.strokeColor = .white
        dome.lineWidth = 2
        saucer?.addChild(dome)

        if let saucer = saucer {
            // Set initial position and movement direction
            let startPositionX = Bool.random() ? -30 : size.width + 30
            let targetPositionX = startPositionX < 0 ? size.width + 30 : -30
            let startPositionY = CGFloat.random(in: size.height / 2...size.height - 50)

            saucer.position = CGPoint(x: startPositionX, y: startPositionY)
            saucer.physicsBody = SKPhysicsBody(polygonFrom: path)
            saucer.physicsBody?.categoryBitMask = PhysicsCategory.saucer
            saucer.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile
            saucer.physicsBody?.collisionBitMask = 0 // Prevent collision with player
            saucer.physicsBody?.affectedByGravity = false
            saucer.physicsBody?.isDynamic = true

            addChild(saucer)

            // Play saucer sound continuously while the saucer is on screen
            if let soundURL = Bundle.main.url(forResource: "saucerBig", withExtension: "wav") {
                do {
                    saucerAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    saucerAudioPlayer?.numberOfLoops = -1 // Infinite loop
                    saucerAudioPlayer?.play()
                } catch {
                    print("Error: Could not load or play Big saucer sound.")
                }
            }

            let moveAction = SKAction.moveTo(x: targetPositionX, duration: 8.0)
            let removeAction = SKAction.run { [weak self] in
                self?.removeSaucer(saucer)
            }
            let sequence = SKAction.sequence([moveAction, removeAction])
            saucer.run(sequence)


            // Schedule saucer to shoot bullets at the player
            let fireBulletAction = SKAction.run { [weak self] in
                self?.saucerShootBullet(from: saucer)
            }
            let waitAction = SKAction.wait(forDuration: 1.5)
            let fireSequence = SKAction.sequence([fireBulletAction, waitAction])
            let repeatFire = SKAction.repeatForever(fireSequence)
            saucer.run(repeatFire)
        }
    }

    // Saucer shoots bullet at player
    func saucerShootBullet(from saucerNode: SKSpriteNode) {
        let bullet = SKSpriteNode(color: .red, size: CGSize(width: 4, height: 10))
        bullet.position = saucerNode.position
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.saucerProjectile
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player // Only contact the player
        bullet.physicsBody?.collisionBitMask = 0 // Prevent collision with anything else
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.linearDamping = 0
        bullet.physicsBody?.angularDamping = 0
        bullet.physicsBody?.allowsRotation = false

        // Calculate direction towards player with random misalignment
        let dx = player.position.x - saucerNode.position.x
        let dy = player.position.y - saucerNode.position.y
        let angle = atan2(dy, dx)
        let misalignment = CGFloat.random(in: -0.5...0.5) // Larger range for less accuracy

        let bulletSpeed: CGFloat = 400.0
        bullet.physicsBody?.velocity = CGVector(dx: cos(angle + misalignment) * bulletSpeed, dy: sin(angle + misalignment) * bulletSpeed)

        addChild(bullet)
        saucerProjectiles.append(bullet) // Add bullet to saucerProjectiles array
    }

    func removeSaucer(_ saucer: SKSpriteNode) {
        print (#function)

        // Stop the sound associated with the saucer
        if saucer == smallSaucer {
            if smallSaucerAudioPlayer?.isPlaying == true {
                smallSaucerAudioPlayer?.stop()
                smallSaucerAudioPlayer = nil
            }
        } else {
            if saucerAudioPlayer?.isPlaying == true {
                saucerAudioPlayer?.stop()
                saucerAudioPlayer = nil
            }
        }

        // Remove the saucer from the scene
        saucer.removeFromParent()
    }

    func destroySaucer(_ saucer: SKSpriteNode) {
        print(#function)

        // Stop the sound if the saucer is being destroyed
        removeSaucer(saucer)

        // Play the appropriate sound effect
        run(bangSSound) // Play a sound when the saucer is destroyed

        // Update score
        if saucer == smallSaucer {
            score += 500
        } else {
            score += 250
        }
        //scoreLabel.text = "Score: \(score)"
    }

    func removeSmallSaucer(_ smallSaucer: SKSpriteNode) {
        removeSaucer(smallSaucer) // Use the generalized removeSaucer function
    }

    //MARK: - Small Saucer
    // Setup small flying saucer
    func setupSmallSaucer() {
        print (#function)

        // Create the small saucer base as a rhombus
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -10, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -7))
        path.addLine(to: CGPoint(x: 10, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 7))
        path.closeSubpath()

        smallSaucer = SKSpriteNode()
        let base = SKShapeNode(path: path)
        base.fillColor = .black
        base.strokeColor = .white
        base.lineWidth = 2
        smallSaucer?.addChild(base)

        // Create a semicircle dome for the top of the small saucer
        let domePath = CGMutablePath()
        domePath.addArc(center: CGPoint(x: 0, y: 3), radius: 3, startAngle: 0, endAngle: .pi, clockwise: false)
        let dome = SKShapeNode(path: domePath)
        dome.fillColor = .black
        dome.strokeColor = .white
        dome.lineWidth = 2
        smallSaucer?.addChild(dome)

        if let smallSaucer = smallSaucer {
            // Set initial position and movement direction
            let startPositionX = Bool.random() ? -30 : size.width + 30
            let targetPositionX = startPositionX < 0 ? size.width + 30 : -30
            let startPositionY = CGFloat.random(in: size.height / 2...size.height - 50)

            smallSaucer.position = CGPoint(x: startPositionX, y: startPositionY)
            smallSaucer.physicsBody = SKPhysicsBody(polygonFrom: path)
            smallSaucer.physicsBody?.categoryBitMask = PhysicsCategory.saucer
            smallSaucer.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile
            smallSaucer.physicsBody?.collisionBitMask = PhysicsCategory.playerProjectile // Prevent collision with player
            smallSaucer.physicsBody?.affectedByGravity = false
            smallSaucer.physicsBody?.isDynamic = true

            addChild(smallSaucer)

            // Load and play sound using AVAudioPlayer
            if let soundURL = Bundle.main.url(forResource: "saucerSmall", withExtension: "wav") {
                do {
                    smallSaucerAudioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    smallSaucerAudioPlayer?.numberOfLoops = -1 // Infinite loop
                    smallSaucerAudioPlayer?.play()
                } catch {
                    print("Error: Could not load or play small saucer sound.")
                }
            }

            let moveAction = SKAction.moveTo(x: targetPositionX, duration: 8.0)
            let removeAction = SKAction.run { [weak self] in
                self?.removeSmallSaucer(smallSaucer)
            }
            let sequence = SKAction.sequence([moveAction, removeAction])
            smallSaucer.run(sequence)

            // Schedule small saucer to shoot bullets at the player
            let fireBulletAction = SKAction.run { [weak self] in
                self?.saucerShootBullet(from: smallSaucer)
            }
            let waitAction = SKAction.wait(forDuration: 2.0) // Small saucer fires slightly slower
            let fireSequence = SKAction.sequence([fireBulletAction, waitAction])
            let repeatFire = SKAction.repeatForever(fireSequence)
            smallSaucer.run(repeatFire)
        }
    }

    //MARK: - Asteroid
    func createAsteroidPath(size: AsteroidSize) -> CGPath {
        let path = CGMutablePath()
        let randomShape = Int.random(in: 0...2) // Randomize between 3 different shapes

        switch (size, randomShape) {
        case (.large, 0):
            // Convex shape
            path.move(to: CGPoint(x: 0, y: 30))
            path.addLine(to: CGPoint(x: -20, y: 15))
            path.addLine(to: CGPoint(x: -30, y: -10))
            path.addLine(to: CGPoint(x: -15, y: -25))
            path.addLine(to: CGPoint(x: 5, y: -35)) // Convex part
            path.addLine(to: CGPoint(x: 10, y: -30))
            path.addLine(to: CGPoint(x: 25, y: -15))
            path.addLine(to: CGPoint(x: 30, y: 10))
        case (.large, 1):
            // Concave shape
            path.move(to: CGPoint(x: 0, y: 35))
            path.addLine(to: CGPoint(x: -25, y: 20))
            path.addLine(to: CGPoint(x: -20, y: -15))
            path.addLine(to: CGPoint(x: -5, y: -5)) // Concave part
            path.addLine(to: CGPoint(x: 5, y: -30))
            path.addLine(to: CGPoint(x: 20, y: -25))
            path.addLine(to: CGPoint(x: 30, y: 5))
        case (.large, 2):
            // Normal shape
            path.move(to: CGPoint(x: 0, y: 32))
            path.addLine(to: CGPoint(x: -15, y: 25))
            path.addLine(to: CGPoint(x: -25, y: -5))
            path.addLine(to: CGPoint(x: -10, y: -20))
            path.addLine(to: CGPoint(x: 15, y: -30))
            path.addLine(to: CGPoint(x: 30, y: 0))
        case (.medium, 0):
            // Normal shape
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: -15, y: 10))
            path.addLine(to: CGPoint(x: -20, y: -5))
            path.addLine(to: CGPoint(x: -10, y: -15))
            path.addLine(to: CGPoint(x: 8, y: -18))
            path.addLine(to: CGPoint(x: 18, y: -10))
            path.addLine(to: CGPoint(x: 20, y: 5))
        case (.medium, 1):
            // Concave shape
            path.move(to: CGPoint(x: 0, y: 25))
            path.addLine(to: CGPoint(x: -10, y: 15))
            path.addLine(to: CGPoint(x: -18, y: -8))
            path.addLine(to: CGPoint(x: -5, y: -10)) // Concave part
            path.addLine(to: CGPoint(x: -5, y: -20))
            path.addLine(to: CGPoint(x: 15, y: -18))
            path.addLine(to: CGPoint(x: 20, y: -5))
        case (.medium, 2):
            // Normal shape
            path.move(to: CGPoint(x: 0, y: 22))
            path.addLine(to: CGPoint(x: -12, y: 8))
            path.addLine(to: CGPoint(x: -15, y: -12))
            path.addLine(to: CGPoint(x: 0, y: -20))
            path.addLine(to: CGPoint(x: 12, y: -10))
            path.addLine(to: CGPoint(x: 18, y: 5))
        case (.small, 0):
            // Normal shape
            path.move(to: CGPoint(x: 0, y: 10))
            path.addLine(to: CGPoint(x: -8, y: 5))
            path.addLine(to: CGPoint(x: -10, y: -3))
            path.addLine(to: CGPoint(x: -5, y: -8))
            path.addLine(to: CGPoint(x: 4, y: -9))
            path.addLine(to: CGPoint(x: 9, y: -5))
            path.addLine(to: CGPoint(x: 10, y: 2))
        case (.small, 1):
            // Concave shape
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: -5, y: 6))
            path.addLine(to: CGPoint(x: -8, y: -4))
            path.addLine(to: CGPoint(x: -2, y: -2)) // Concave part
            path.addLine(to: CGPoint(x: 0, y: -10))
            path.addLine(to: CGPoint(x: 7, y: -6))
            path.addLine(to: CGPoint(x: 10, y: 3))
        case (.small, 2):
            // Normal shape
            path.move(to: CGPoint(x: 0, y: 11))
            path.addLine(to: CGPoint(x: -6, y: 3))
            path.addLine(to: CGPoint(x: -9, y: -5))
            path.addLine(to: CGPoint(x: -3, y: -8))
            path.addLine(to: CGPoint(x: 5, y: -9))
            path.addLine(to: CGPoint(x: 10, y: 0))
        default:
            break
        }
        path.closeSubpath()
        return path
    }

    // Spawn asteroids
    func spawnAsteroids(count: Int) {
        print(#function)

        for _ in 0..<count {
            var randomX: CGFloat = 0
            var randomY: CGFloat = 0

            // Ensure that asteroids do not spawn close to the player
            repeat {
                randomX = CGFloat.random(in: 0...size.width)
                randomY = CGFloat.random(in: 0...size.height)
            } while distance(from: CGPoint(x: randomX, y: randomY), to: player.position) < 150 // Increased minimum distance from the player

            // Randomly choose asteroid size
            let randomSize = AsteroidSize.large

            // Create asteroid based on its size
            let path = createAsteroidPath(size: randomSize)
            let asteroid = SKSpriteNode()
            let shape = SKShapeNode(path: path)
            shape.fillColor = .clear
            shape.strokeColor = .white
            shape.lineWidth = 2
            asteroid.addChild(shape)

            // Set random position on screen
            asteroid.position = CGPoint(x: randomX, y: randomY)

            // Configure physics body
            asteroid.physicsBody = SKPhysicsBody(polygonFrom: path)
            asteroid.physicsBody?.categoryBitMask = PhysicsCategory.asteroid
            asteroid.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.player
            asteroid.physicsBody?.collisionBitMask = 0
            asteroid.physicsBody?.affectedByGravity = false
            asteroid.physicsBody?.linearDamping = 0

            // Set velocity based on asteroid size
            let velocityMultiplier: CGFloat
            switch randomSize {
            case .large:
                velocityMultiplier = 1.0
            case .medium:
                velocityMultiplier = 1.1
            case .small:
                velocityMultiplier = 1.2
            }

            asteroid.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -150...150) * velocityMultiplier,
                                                      dy: CGFloat.random(in: -150...150) * velocityMultiplier)

            // Set scale for visual distinction
            let scale: CGFloat
            switch randomSize {
            case .large:
                scale = 1.0
            case .medium:
                scale = 0.9
            case .small:
                scale = 0.9
            }
            asteroid.setScale(scale)

            addChild(asteroid)
            asteroids.append(asteroid)
        }
    }

    // Destroy asteroid
    func destroyAsteroid(_ asteroid: SKSpriteNode) {
        if asteroid.xScale == 1.0 {
            // Spawn two medium asteroids
            spawnSplitAsteroids(from: asteroid, newSize: .medium)
        } else if asteroid.xScale == 0.75 {
            // Spawn two small asteroids
            spawnSplitAsteroids(from: asteroid, newSize: .small)
        }

        // Play sound and remove the asteroid
        run(bangLSound)
        asteroid.removeFromParent()
        asteroids.removeAll { $0 == asteroid }
        score += 100
        //scoreLabel.text = "Score: \(score)"
    }

    func spawnSplitAsteroids(from asteroid: SKSpriteNode, newSize: AsteroidSize) {
        for _ in 0..<2 {
            let path = createAsteroidPath(size: newSize)
            let smallAsteroid = SKSpriteNode()
            let shape = SKShapeNode(path: path)
            shape.fillColor = .clear
            shape.strokeColor = .white
            shape.lineWidth = 2
            smallAsteroid.addChild(shape)
            smallAsteroid.position = asteroid.position
            smallAsteroid.physicsBody = SKPhysicsBody(polygonFrom: path)
            smallAsteroid.physicsBody?.categoryBitMask = PhysicsCategory.asteroid
            smallAsteroid.physicsBody?.contactTestBitMask = PhysicsCategory.playerProjectile | PhysicsCategory.player
            smallAsteroid.physicsBody?.collisionBitMask = 0
            smallAsteroid.physicsBody?.affectedByGravity = false
            smallAsteroid.physicsBody?.linearDamping = 0

            // Set velocity for the new smaller asteroids
            let velocityMultiplier: CGFloat = (newSize == .medium) ? 1.1 : 1.2

            smallAsteroid.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -150...150) * velocityMultiplier,
                                                           dy: CGFloat.random(in: -150...150) * velocityMultiplier)

            // Set scale for visual distinction
            smallAsteroid.setScale((newSize == .medium) ? 0.75 : 0.65)

            addChild(smallAsteroid)
            asteroids.append(smallAsteroid)
        }
    }

    //MARK: - GAME
    // Game initialization
    override func didMove(to view: SKView) {
        print (#function)
        self.anchorPoint = CGPoint(x: 0, y: 0)
        self.size = view.bounds.size
        backgroundColor = .black
        physicsWorld.contactDelegate = self

        //isPaused = true

        setupHUD()
        setupPlayer()
        setupThrustAnimation()
        setupInstructions() // Add the instructions at the beginning
    }


    // Handle collision between physics bodies
    func didBegin(_ contact: SKPhysicsContact) {
        print (#function)
        let firstBody = contact.bodyA
        let secondBody = contact.bodyB

        if firstBody.categoryBitMask == PhysicsCategory.playerProjectile && secondBody.categoryBitMask == PhysicsCategory.asteroid {
            if let asteroid = secondBody.node as? SKSpriteNode, let projectile = firstBody.node as? SKSpriteNode {
                destroyAsteroid(asteroid)
                projectile.removeFromParent()
                projectiles.removeAll { $0 == projectile }
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.asteroid && secondBody.categoryBitMask == PhysicsCategory.playerProjectile {
            if let asteroid = firstBody.node as? SKSpriteNode, let projectile = secondBody.node as? SKSpriteNode {
                destroyAsteroid(asteroid)
                projectile.removeFromParent()
                projectiles.removeAll { $0 == projectile }
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.asteroid && secondBody.categoryBitMask == PhysicsCategory.player {
            if let asteroid = firstBody.node as? SKSpriteNode {
                playerHit(by: asteroid)
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.player && secondBody.categoryBitMask == PhysicsCategory.asteroid {
            if let asteroid = secondBody.node as? SKSpriteNode {
                playerHit(by: asteroid)
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.saucer && secondBody.categoryBitMask == PhysicsCategory.playerProjectile {
            if let saucer = firstBody.node as? SKSpriteNode, let projectile = secondBody.node as? SKSpriteNode {
                destroySaucer(saucer)
                projectile.removeFromParent()
                projectiles.removeAll { $0 == projectile }
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.playerProjectile && secondBody.categoryBitMask == PhysicsCategory.saucer {
            if let saucer = secondBody.node as? SKSpriteNode, let projectile = firstBody.node as? SKSpriteNode {
                destroySaucer(saucer)
                projectile.removeFromParent()
                projectiles.removeAll { $0 == projectile }
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.saucerProjectile && secondBody.categoryBitMask == PhysicsCategory.player {
            if let _ = secondBody.node as? SKSpriteNode, let bullet = firstBody.node as? SKSpriteNode {
                playerHit(by: bullet)
                bullet.removeFromParent()
                projectiles.removeAll { $0 == bullet }
            }
        } else if firstBody.categoryBitMask == PhysicsCategory.player && secondBody.categoryBitMask == PhysicsCategory.saucerProjectile {
            if let _ = firstBody.node as? SKSpriteNode, let bullet = secondBody.node as? SKSpriteNode {
                playerHit(by: bullet)
                bullet.removeFromParent()
                projectiles.removeAll { $0 == bullet }
            }
        }
    }

    // Setup Heads-Up Display (HUD)
    func setupHUD() {
        print (#function)

        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontColor = .white
        scoreLabel.fontSize = 20
        scoreLabel.position = CGPoint(x: 70, y: size.height - 100)
        addChild(scoreLabel)

        highScoreLabel = SKLabelNode(text: "High Score: \(highScore)")
        highScoreLabel.fontColor = .white
        highScoreLabel.fontSize = 20
        highScoreLabel.position = CGPoint(x: size.width - 210, y: size.height - 100)
        addChild(highScoreLabel)

        livesLabel = SKLabelNode(text: "Lives: 3")
        livesLabel.fontColor = .white
        livesLabel.fontSize = 20
        livesLabel.position = CGPoint(x: size.width - 70, y: size.height - 100)
        addChild(livesLabel)
    }

    // Calculate distance between two points
    func distance(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
        let dx = pointA.x - pointB.x
        let dy = pointA.y - pointB.y
        return sqrt(dx * dx + dy * dy)
    }

    func setupInstructions() {
        print (#function)

        instructionsLabel = SKLabelNode(text: "Instructions: Tap to shoot, drag to move.")
        instructionsLabel.fontColor = .white
        instructionsLabel.fontSize = 20
        instructionsLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80)
        addChild(instructionsLabel)

        tapToStartLabel = SKLabelNode(text: "Tap to Start")
        tapToStartLabel.fontColor = .yellow
        tapToStartLabel.fontSize = 30
        tapToStartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 100)
        addChild(tapToStartLabel)

        asteroidsLabel = SKLabelNode(text: "SWIFTOIDS")
        asteroidsLabel.fontColor = .white
        asteroidsLabel.fontSize = 50
        asteroidsLabel.name = "asteroidsLabel"
        asteroidsLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 150)
        addChild(asteroidsLabel)

    }
    // Remove all saucer projectiles
    func removeAllSaucerProjectiles() {
        for projectile in saucerProjectiles {
            projectile.removeFromParent()
        }
        saucerProjectiles.removeAll()
    }

    func startGame() {
        print(#function)

        // Remove all remaining asteroids from the previous game
        for asteroid in asteroids {
            asteroid.removeFromParent()
        }
        asteroids.removeAll()

        // Remove all remaining projectiles from the previous game
        for projectile in projectiles {
            projectile.removeFromParent()
        }

        projectiles.removeAll()
        projectileLifetimes.removeAll()

        // Remove labels if they exist
        if instructionsLabel != nil {
            instructionsLabel.removeFromParent()
        }

        if tapToStartLabel != nil {
            tapToStartLabel.removeFromParent()
        }

        if gameOverLabel != nil {
            gameOverLabel.removeFromParent()
        }

        if restartLabel != nil {
            restartLabel.removeFromParent()
        }

        if let shape = player.childNode(withName: "spaceshipShape") as? SKShapeNode {
            shape.fillColor = SKColor.black
        }

         // Reset game state variables
        isGameStarted = true
        lives = 3
        score = 0
        level = 1
        isPaused = false

        // Reposition the player and spawn initial asteroids and saucers
        repositionPlayer()
        spawnAsteroids(count: 5)
        spawnSaucer()

        // Fade out the title label
        let fadeOutAction = SKAction.fadeOut(withDuration: 3.0)
        let removeAction = SKAction.removeFromParent()
        let sequence = SKAction.sequence([fadeOutAction, removeAction])
        if  let tmpLbl = childNode(withName: "asteroidsLabel") as? SKLabelNode {
            asteroidsLabel.run(sequence)
        }
    }


    //MARK: - Saucer Handling
    func spawnSaucer() {
        print (#function)

        let randomTime = Double.random(in: 5.0...15.0) // Random time between 5 and 15 seconds
        let spawnSaucerAction = SKAction.run { [weak self] in
            if Bool.random() {
                self?.setupSaucer()
            } else {
                self?.setupSmallSaucer()
            }
        }
        run(SKAction.sequence([SKAction.wait(forDuration: randomTime), spawnSaucerAction]))
    }

    // Game over logic
    func gameOver() {
        print (#function)

        removeAllSaucerProjectiles()

        // Remove all projectiles from the screen
        for projectile in projectiles {
            projectile.removeFromParent()
        }

        projectiles.removeAll()

        // Stop any ongoing saucer sounds and remove saucers
        if let saucer = saucer {
            removeSaucer(saucer)
        }
        if let smallSaucer = smallSaucer {
            removeSaucer(smallSaucer)
        }

        asteroidsLabel = SKLabelNode(text: "SWIFTOIDS")
        asteroidsLabel.fontColor = .white
        asteroidsLabel.fontSize = 50
        asteroidsLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 70)
        asteroidsLabel.name = "asteroidsLabel"
        addChild(asteroidsLabel)

        gameOverLabel = SKLabelNode(text: "Game Over")
        gameOverLabel.fontColor = .red
        gameOverLabel.fontSize = 40
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(gameOverLabel)

        // Pause the game
        isPaused = true

        // Update high score if necessary
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "highScore")
            highScoreLabel.text = "High Score: \(highScore)"
        }

        // Add restart instruction
        restartLabel = SKLabelNode(text: "Tap to Restart")
        restartLabel.fontColor = .white
        restartLabel.fontSize = 20
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        restartLabel.name = "restartLabel"
        addChild(restartLabel)
  }


    // Level complete logic
    func levelComplete() {
        print (#function)

        isLevelComplete = true
        levelCompleteLabel = SKLabelNode(text: "Level Complete")
        levelCompleteLabel.fontColor = .green
        levelCompleteLabel.fontSize = 40
        levelCompleteLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(levelCompleteLabel)

        // Wait for 1 second, then start the next wave
        let wait = SKAction.wait(forDuration: 1.0)
        let startNextWave = SKAction.run { [weak self] in
            self?.levelCompleteLabel.removeFromParent()
            self?.isLevelComplete = false
            self?.repositionPlayer()
            self?.spawnAsteroids(count: 5 + self!.level) // Increase asteroid count with each level
            //self?.setupSaucer() // Spawn the saucer at the start of each level
        }

        lives += 1

        run(SKAction.sequence([wait, startNextWave]))

        let randomTime = Double.random(in: 5.0...15.0) // Random time between 5 and 15 seconds
        let spawnSaucerAction = SKAction.run { [weak self] in
            if Bool.random() {
                self?.setupSaucer()
            } else {
                self?.setupSmallSaucer()
            }
        }
        run(SKAction.sequence([SKAction.wait(forDuration: randomTime), spawnSaucerAction]))

    }


    //MARK: - USER INPUT
    // Handle user input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)
        let nodesAtPoint = nodes(at: touchLocation)

        // Start the game if not started
        if !isGameStarted {
            startGame()
            return
        }

        // Check if game is over and restart was requested
        if isPaused, nodesAtPoint.contains(where: { $0 is SKLabelNode && ($0 as! SKLabelNode).text == "Tap to Restart" }) {
            startGame()
            return
        }

        let angle = atan2(touchLocation.y - player.position.y, touchLocation.x - player.position.x) - .pi / 2
        player.zRotation = angle

        // Fire a projectile on a short tap
        fireProjectile(currentTime: CACurrentMediaTime())
    }



    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)
        let angle = atan2(touchLocation.y - player.position.y, touchLocation.x - player.position.x) - .pi / 2
        player.zRotation = angle

        // Apply thrust continuously on long press/move
        applyThrust()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeThrustAnimation()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeThrustAnimation()
    }

    // Wrap-around logic
    func handleWrapAround(for node: SKSpriteNode) {
        if node.position.x > frame.maxX {
            node.position.x = frame.minX
        } else if node.position.x < frame.minX {
            node.position.x = frame.maxX
        }

        if node.position.y > frame.maxY {
            node.position.y = frame.minY
        } else if node.position.y < frame.minY {
            node.position.y = frame.maxY
        }
    }

    //MARK: - GAME LOOP
    // Update function for game loop
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }

        //let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        if asteroids.isEmpty && !isPaused && !isLevelComplete && isGameStarted {
            levelComplete()
        }
        for asteroid in asteroids {
            handleWrapAround(for: asteroid)
        }
        for projectile in projectiles {
            handleProjectileWrapAround(for: projectile)

            // Lifetime check for projectiles
            if let initialTime = projectileLifetimes[projectile] {
                let elapsedTime = currentTime - initialTime
                if elapsedTime > 0.5 { // Maximum lifetime of 5 seconds
                    projectile.removeFromParent()
                    projectiles.removeAll { $0 == projectile }
                    projectileLifetimes.removeValue(forKey: projectile)
                }
            }
        }
        handleWrapAround(for: player)
    }
}
