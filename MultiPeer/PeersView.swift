//  Created by warren on 12/4/22.

import SwiftUI

struct PeersView: View {
    @ObservedObject var peersVm: PeersVm
    var body: some View {
        VStack(alignment:.leading) {
            HStack {
                Image(systemName: "globe")
                    .imageScale(.medium)
                    .foregroundColor(.accentColor)
                Text(peersVm.peerTitle)
            }
            Text(peersVm.peerList)
        }
        .padding()
    }
}
