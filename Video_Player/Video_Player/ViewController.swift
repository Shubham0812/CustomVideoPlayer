//
//  ViewController.swift
//  Video_Player
//
//  Created by Shubham on 22/05/25.
/// CONTENT by ``@SHUBHAM_IOSDEV``

import UIKit
import AVFoundation // Required for audio / video playback
import AVKit        // Required for AVPictureInPicture Controller - PIP Player

class ViewController: UIViewController {
    
    
    // MARK: - Variables
    private let containerView: UIView = .init()
    private let overlayView: UIView = .init()
    
    private let playPauseButton: UIButton = .init(type: .system) // Play/Pause button
    private let pipButton: UIButton = .init(type: .system)  // PIP button
    
    private let progressView: UIProgressView = .init(progressViewStyle: .default)
    
    // AV Player Components
    
    private var player: AVPlayer!
    
    private var playerLayer: AVPlayerLayer!
    
    private var pipController: AVPictureInPictureController?
    
    private var timeObserverToken: Any?
    
    private var hasEnded = false
    
    // Constraint to maintain the aspect ratio of the Video
    private var aspectConstraint: NSLayoutConstraint?
    
    
    
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupAudioSession()
        setupUI()
        loadVideo()
        observeEndNotifcation()
        observeAppState()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure Player's Layer matches the Container Size when Layout changes
        playerLayer?.frame = containerView.bounds
    }
    
    deinit {
        // Clean up resources when View Controller is deallocated - Extended Views
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        
        NotificationCenter.default.removeObserver(self)
        // The last step remaining is to Enable the Background mode capability - to Play the Video in PIP
    }
    
    
    // MARK: - @OBJC & Outlet Functions
    @objc func handleOverlayTap(_ sender: UITapGestureRecognizer) {
        overlayView.isHidden.toggle() // toggle the isHidden property to show / hide the overlay view
    }
    
    @objc func togglePlayPause() {
        guard let player else { return }
        
        if hasEnded {
            // If the Video has ended, seek the Video to the beginning and restart
            player.seek(to: .zero) { _ in
                self.hasEnded = false
                self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            }
        } else if player.timeControlStatus == .playing {
            // If the video is playing, pause the Video
            player.pause()
            self.playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            // if the Video is starting for the first time, hide the Overlay View
            if player.currentTime() == .zero {
                overlayView.isHidden = true
            }
            
            // If the Video is paused, play the Video
            player.play()
            self.playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
        
    }
    
    @objc func toggleInlinePIP() {
        guard let pip = pipController else { return }
        
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
    }
    
    @objc func didEnterBackground() {
        guard let pip = pipController, !pip.isPictureInPictureActive else { return }
        pip.startPictureInPicture() // starts the External Picture in Picture capabilities
    }
    
    @objc func videoEnded() {
        hasEnded = true
        playPauseButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
    }
    
    
    // MARK: - Functions
    
    // Configures the Audio Settings
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback) // .Playback allows playback when muted
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession Error -> \(error)")
        }
    }
    
    // Set up the UI Elements
    func setupUI() {
        // Configure Container View for UI Components
        containerView.backgroundColor = .white.withAlphaComponent(0.35)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        // Tap gesture to hide the Overlay View
        let containerViewTapGesture: UITapGestureRecognizer = .init(target: self, action: #selector(handleOverlayTap))
        containerView.addGestureRecognizer(containerViewTapGesture)
        
        overlayView.backgroundColor = .black.withAlphaComponent(0.25)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(overlayView) // add the Overlay View to the Container View
        
        containerView.bringSubviewToFront(overlayView) // bring the Overlay View to the front
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        // Constraints for the Overlay View
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
        
        // To Maintain the 16:9 ratio of the Video we'll use the aspectConstraint that we declared above as a Variable
        aspectConstraint = containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 9 / 16)
        aspectConstraint?.isActive = true
        
        // Let's add the Play / Pause and the Progress Button
        
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.backgroundColor = .black.withAlphaComponent(0.5)
        playPauseButton.layer.cornerRadius = 26
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        
        // Add the Play/Pause button to the Overlay View
        overlayView.addSubview(playPauseButton)
        
        NSLayoutConstraint.activate([
            playPauseButton.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 58),
            playPauseButton.heightAnchor.constraint(equalToConstant: 58),
        ])
        
        progressView.progress = 0
        progressView.tintColor = .black.withAlphaComponent(0.5)
        progressView.progressTintColor = .white
        progressView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 6)
        ])
        
        // Configure the PiP Button for the Video Overlay Container View
        pipButton.setTitle("PiP ↗︎", for: .normal)
        pipButton.translatesAutoresizingMaskIntoConstraints = false
        pipButton.addTarget(self, action: #selector(toggleInlinePIP), for: .touchUpInside)
        view.addSubview(pipButton)
        
        NSLayoutConstraint.activate([
            pipButton.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 16),
            pipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    
    
    // Load & Prepare the Video
    func loadVideo() {
        // Sample Video URL
        guard let url = URL(string: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4") else { return }
        
        let asset = AVAsset(url: url) // initialse the AVAsset
        
        Task {
            do {
                let _ = try await asset.load(.tracks)
                
                // Get the Video Track to determine the Video's dimensions
                guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { return }
                
                // Extract the Original aspect ratio of the Video
                let size = try await videoTrack.load(.naturalSize)
                let ratio = size.height / size.width
                
                // Update the UI on the Main Thread
                DispatchQueue.main.async {
                    self.aspectConstraint?.isActive = false
                    self.aspectConstraint = self.containerView.heightAnchor.constraint(equalTo: self.containerView.widthAnchor, multiplier: ratio)
                    self.aspectConstraint?.isActive = true
                    self.view.layoutIfNeeded()
                    
                    // Create and configure the AVPlayer with the asset
                    let item = AVPlayerItem(asset: asset)
                    self.player = AVPlayer(playerItem: item)
                    
                    self.playerLayer = AVPlayerLayer(player: self.player)
                    self.playerLayer.videoGravity = .resizeAspect
                    
                    // Add the Player Layer to the Container View's Layer
                    self.containerView.layer.insertSublayer(self.playerLayer, at: 0)
                    self.playerLayer.frame = self.containerView.bounds
                    
                    // Set up Picture-in-Picture if supported by the Device
                    if AVPictureInPictureController.isPictureInPictureSupported() {
                        self.pipController = AVPictureInPictureController(playerLayer: self.playerLayer)
                        self.pipController?.delegate = self
                    }
                    
                    // Set up time observer to update the Progress Bar
                    self.addPeriodicTimeObserver()
                }
                
                
            } catch {
                print("Failed to load Video ->", error)
            }
        }
    }
    
    // Register for end-of-playback notification
    func observeEndNotifcation() {
        guard player != nil else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(videoEnded), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    // Register for app state changes
    func observeAppState() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    func addPeriodicTimeObserver() {
        guard let player else { return }
        // Create timer for periodic updates ( once per second )
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, let duration = self.player.currentItem?.duration.seconds else { return }
            
            // Animate the Progress Bar
            UIView.animate(withDuration: 1, delay: 0, options: .curveLinear) {
                self.progressView.setProgress(Float(time.seconds) / Float(duration), animated: true)
                self.view.layoutIfNeeded()
            }
        }
    }
}

// MARK: - AVPicture in Picture Delegates
extension ViewController: AVPictureInPictureControllerDelegate {
    
    // This delegate function is called just before the start of PIP
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        containerView.isHidden = true
    }
    
    // This function is called when the PIP mode ends
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        containerView.isHidden = false
    }
    
    // This function is called whwn the PIP mode fails to start
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: any Error) {
        print("Entering the PIP Mode failed", error)
    }
}


