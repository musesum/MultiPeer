// Created by musesum on 12/4/22.

import UIKit
import MultipeerConnectivity

public protocol PeersControllerDelegate: AnyObject {
    func didChange()
    func received(message: [String: Any], viaStream: Bool)
}

public typealias PeerName = String

/// advertise and browse for peers via Bonjour
public class PeersController: NSObject {

    public static var shared = PeersController()

    /// Info.plist values for this service are:
    ///
    ///     Bonjour Services
    ///        _multipeer-test._tcp
    ///        _multipeer-test._udp
    ///
    let serviceType = "multipeer-test"

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private let startTime = Date().timeIntervalSince1970

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private var inputStream: InputStream?
    private var peerStream = [MCPeerID: OutputStream]()

    public var peerState = [PeerName: MCSessionState]()
    public var hasPeers = false
    public var peersDelegates = [any PeersControllerDelegate]()
    public func remove(peersDelegate: any PeersControllerDelegate) {
        peersDelegates = peersDelegates.filter { return $0 !== peersDelegate }
    }
    public lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerID)
        session.delegate = self
        return session
    }()
    public lazy var myName: PeerName = {
        return session.myPeerID.displayName
    }()

    override init() {
        super.init()
        startAdvertising()
        startBrowsing()
    }
    deinit {
        stopServices()
        session.disconnect()
        session.delegate = nil
    }

    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    private func stopServices() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil

        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
    }

    func logPeer(_ body: PeerName) {

        let elapsedTime = Date().timeIntervalSince1970 - startTime
        let logTime = String(format: "%.2f", elapsedTime)
        print("⚡️ \(logTime) \(myName): \(body)")
    }
}

extension PeersController {
    
    /// send message to peers via MCSessionDelegate
    public func sendSessionMessage(_ message: [String : Any]) {
        
        if session.connectedPeers.isEmpty {
            print("🚫", terminator: "")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: .prettyPrinted)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("⚡️sendMessage error: \(error.localizedDescription)")
            return
        }
    }

    /// send message to peers
    public func sendMessage(_ message: [String : Any],
                            viaStream: Bool = true) {

        if session.connectedPeers.isEmpty {
            print("🚫", terminator: "")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: .prettyPrinted)

            if viaStream {
                for peerID in session.connectedPeers {
                    let peerName = peerID.displayName
                    if let outputStream = getStream(peerName, peerID: peerID) {
                        outputStream.open()
                        let count = outputStream.write(data.bytes, maxLength: data.bytes.count)
                        logPeer("💧output: \"\(peerName)\" bytes: \(count)")
                    }
                }
            } else {
                // via session
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
                logPeer("⚡️send toPeers")
            }
        } catch {
            logPeer("sendMessage error: \(error.localizedDescription)")
            return
        }
    }

    func getStream(_ streamName: String, peerID: MCPeerID) -> OutputStream? {

        if let stream = peerStream[peerID]  {
            return stream
        } else if let outputStream = try? session.startStream(withName: streamName, toPeer: peerID) {

            outputStream.delegate = self
            outputStream.schedule(in: .main,  forMode: .common)

            peerStream[peerID] = outputStream
            logPeer("💧outputStream: toPeer: \(peerID.displayName)")
            return outputStream
        } else {
            logPeer("💧⁉️")
            return nil
        }
    }
    /** Sometimes a .notConnect state is sent from peer and yet still receiving messaages.

   There is a long standing GCKSession issue that throws up a NSLog:

        [GCKSession] Not in connected state, so giving up for participant ...
        // not sure if this is related to false .nonConnected
     */
     func fixConnectedState(for peerName: String) {
        peerState[peerName] = .connected
    }

}
