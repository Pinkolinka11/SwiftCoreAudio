//
//  AudioSystem.swift
//  VSXSystemwide
//
//  Created by Devin Roth on 2023-01-10.
//

import Foundation
import CoreAudio

class AudioSystem: ObservableObject {
    public static let shared: AudioSystem = AudioSystem()
    
    public var defaultOutput: AudioDevice? {
        get {
            
            // get the device ID
            var inAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeWildcard,
                mElement: kAudioObjectPropertyElementWildcard
            )
            
            var data = AudioObjectID()
            var size = UInt32(MemoryLayout<AudioDeviceID>.stride)
            
            let error = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &inAddress,
                0,
                nil,
                &size,
                &data
            )
            
            guard data != 0 && error == noErr else {
                return nil
            }
            
            return AudioDevice(audioObjectID: data)
        }
        
        set {
            guard let audioObjectID = newValue?.audioObjectID else {
                return
            }
            
            var inAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeWildcard,
                mElement: kAudioObjectPropertyElementWildcard
            )
            
            var data = audioObjectID
            let size = UInt32(MemoryLayout<AudioDeviceID>.stride)
            
            _ = AudioObjectSetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &inAddress,
                0,
                nil,
                size,
                &data
            )
        }
    }
    
    @Published public private(set) var audioDevices = [AudioDevice]()
    
    private init() {
        audioDevices = getAudioDevices()
        addDeviceListListener()
    }
    
    private func getAudioDevices() -> [AudioDevice] {
     
        // setup variables
        var status = noErr
        var inAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeWildcard,
            mElement: kAudioObjectPropertyElementWildcard
        )
        
        // get the size
        var size = UInt32()
        
        status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &inAddress,
            0,
            nil,
            &size
        )

        // get the audio object ids
        var data = [AudioObjectID](repeating: AudioObjectID(), count: Int(size)/MemoryLayout<AudioDeviceID>.stride)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &inAddress,
            0,
            nil,
            &size,
            &data
        )
        
        guard status == noErr else {
            return [AudioDevice]()
        }
        
        // map to audio devices
        let audioDevices =  data.compactMap { AudioDevice(audioObjectID: $0)}
        
        return audioDevices
    }
    
    func addDeviceListListener() {
        // add listener for device changes
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioPlugInPropertyDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // pass pointer to self
        AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            deviceListListenerProc(),
            nil
        )
    }

    func removeDeviceListListener() {
        // add listener for device changes
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioPlugInPropertyDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            deviceListListenerProc(),
            nil
        )
    }
    
    func deviceListListenerProc() -> AudioObjectPropertyListenerProc {
        { _, _, _, _ in
            DispatchQueue.main.async {
                AudioSystem.shared.audioDevices = AudioSystem.shared.getAudioDevices()
            }
            
            return 0
        }
    }
}
