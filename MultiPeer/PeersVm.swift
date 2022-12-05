
import SwiftUI

import MultipeerConnectivity

/// This is a SwiftUI View Model 
class PeersVm: ObservableObject {

    /// myName and one secound counter
    @Published var peerTitle = ""

    /// list of connected peers and their counter
    @Published var peerList = ""

    /// manages
    private var peerController: PeerController
    private var peerMessage = [String: [String:Any]]()

    init() {
        peerController = PeerController()
        peerController.delegate = self
        oneSecondCounter()
    }
    deinit {
        peerController.delegate = nil
    }

    /// create a 1 second counter and send my count to all of my peers
    private func oneSecondCounter() {
        var count = Int(0)
        func loopNext() {
            count += 1
            peerController.sendMessage(["count": count] )
            peerTitle = "\(peerController.myName): \(count)"
        }
        _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true)  {_ in
            loopNext()
        }

    }
}
extension PeersVm: PeerControllerDelegate {

    func didChange() {
        var connectedList = ""
        for (name,state) in peerController.peerState {
            connectedList += "\n" + state.icon() + name

            if let message = peerMessage[name],
               let count = message["count"] as? Int {
                connectedList += ": \(count)"
            }
        }
        self.peerList = connectedList
    }

    func received(message: [String: Any],
                  from peer: MCPeerID) {

        peerMessage[peer.displayName] = message
        didChange()
        
    }
}
