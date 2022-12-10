//
//  PeersC+Stream.swift
//  MultiPeer
//
//  Created by warren on 12/9/22.

import MultipeerConnectivity

extension PeersController: StreamDelegate {

    public func stream(_ stream: Stream,
                       handle eventCode: Stream.Event) {

        if let inputStream = stream as? InputStream,
           inputStream.hasBytesAvailable {

            let data = Data(reading: inputStream)

            do {
                let message = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                if let peerName = message["peerName"] as? String {
                    fixConnectedState(for: peerName)
                    self.logPeer("💧input:  \"\(peerName)\" bytes:\(data.bytes.count) count:\(message.count) ")
                }

                DispatchQueue.main.async {
                    for delegate in self.peersDelegates {
                        delegate.received(message: message, viaStream: true)
                    }
                }
            }
            catch {
                logPeer("💧stream error: \(error.localizedDescription)")
            }
        }
    }
}
