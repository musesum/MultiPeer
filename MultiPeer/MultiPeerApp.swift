//  Created by warren on 12/4/22.

import SwiftUI

@main
struct MultiPeerApp: App {
    var body: some Scene {
        WindowGroup {
            PeersView(peersVm: PeersVm())
        }
    }
}
