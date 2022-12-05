import UIKit
import MultipeerConnectivity

protocol PeerControllerDelegate: AnyObject {
    func didChange() //
    func received(message: [String: Any], from peer: MCPeerID)
}

/// advertise and browse for peers via Bonjour
class PeerController: NSObject {

    /// Info.plist values for this service are:
    ///
    ///     Bonjour Services
    ///        _multipeer-test._tcp
    ///        _multipeer-test._udp
    ///
    let serviceType = "multipeer-test"

    var peerState = [String: MCSessionState]()
    let startTime = Date().timeIntervalSince1970

    /// An object that implements the `SessionControllerDelegate` protocol
    weak var delegate: PeerControllerDelegate?
    
    private let peerID = MCPeerID(displayName: UIDevice.current.name)
    
    public lazy var session: MCSession = {
        let session = MCSession(peer: self.peerID)
        session.delegate = self
        return session
    }()
    public lazy var myName: String = {
        return session.myPeerID.displayName
    }()

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

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
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func startAdvertising() {
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    private func stopServices() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
    }

    func log(_ body: String) {
        let elapsedTime = Date().timeIntervalSince1970 - startTime
        let logTime = String(format: "%.2f", elapsedTime)
        print("⚡️ \(logTime) \(myName): \(body)")
    }
}

extension PeerController: MCSessionDelegate {

    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {

        let displayName = peerID.displayName

       log("session \"\(displayName)\" \(state.description())")

        peerState[displayName] = state

        DispatchQueue.main.async {
            self.delegate?.didChange()
        }
    }
    
    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {

        log("didReceive fromPeer \"\(peerID.displayName)\"")

        /// Sometimes a .notConnect state is sent from peer
        /// and yet still receiving messaages. This may be related to
        /// an outstanding GCKSession issue that throws up a NSLog
        /// `GCKSession] Not in connected state, so giving up for participant [5F13E219] on channel [0].
        ///
        peerState[peerID.displayName] = .connected


        var message = [String: Any]()
        message = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String : Any]
        DispatchQueue.main.async {
            self.delegate?.received(message: message, from: peerID)
        }
    }
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {

        log("didStartReceivingResourceWithName \(resourceName) fromPeer  \"\(peerID.displayName)\" with progress [\(progress)]")
    }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {

        // If error is not nil something went wrong
        if (error != nil) {
            log("didFinishReceivingResourceWithName Error \(String(describing: error)) from \"\(peerID.displayName)\"")
        } else {
            log("didFinishReceivingResourceWithName \(resourceName) from \"\(peerID.displayName)\"")
        }
    }

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {

        log("\(streamName) from \(peerID.displayName)")
    }
}

extension PeerController: MCNearbyServiceBrowserDelegate {

    // Found a nearby advertising peer
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {


        let shouldInvite = (myName.compare(peerID.displayName) == .orderedDescending)

        if shouldInvite {
            log("Inviting \"\(peerID.displayName)\"")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30.0)
        } else {
            log("Not inviting \"\(peerID.displayName)\"")
        }

        delegate?.didChange()
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        log("lostPeer:  \"\(peerID.displayName)\"")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        log("didNotStartBrowsingForPeers: \(error)")
    }
}

extension PeerController: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log("didReceiveInvitationFromPeer:  \"\(peerID.displayName)\"")
        
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        log("didNotStartAdvertisingPeer \(error)")
    }
}
extension PeerController {

    // Creates data object for IoT/net communications and syncs with other player.
    public func sendMessage(_ message: [String : Any]) {
        if session.connectedPeers.isEmpty { return }
        var data : Data
        do {
            data = try JSONSerialization.data(withJSONObject: message, options: .prettyPrinted)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("⚡️sendMessage error: \(error.localizedDescription)")
            return
        }
    }

}
