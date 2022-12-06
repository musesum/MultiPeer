//  Created by musesum on 12/4/22.

import SwiftUI

struct PeersView: View {
    @ObservedObject var peersVm: PeersVm
    var body: some View {
        VStack(alignment:.leading) {
            HStack {
                Image(systemName: "globe")
                    .imageScale(.medium)
                    .foregroundColor(.accentColor)
                Text(peersVm.peersTitle)
            }
            Text(peersVm.peersList)
        }
        .padding()
    }
}
