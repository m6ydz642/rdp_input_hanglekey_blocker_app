//
//  ContentView.swift
//  RDPHangleSwitchKeyInputBlockerApp
//
//  Created by m6ydz642 on 10/9/24.
//

import SwiftUI
import Cocoa
struct ContentView: View {
    @State private var isMonitoring = false
    
    var body: some View {
        VStack {
            Text("Global Key Interceptor")
                .font(.largeTitle)
                .padding()
            
            Toggle(isOn: $isMonitoring) {
                Text(isMonitoring ? "Stop Monitoring" : "Start Monitoring")
            }
            .padding()
            .onChange(of: isMonitoring) { newValue in
                if newValue {
                    startEventTap()  // 모니터링 시작
                } else {
                    stopEventTap()   // 모니터링 중지
                }
            }
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}

// Event Tap 관련 전역 변수
var eventTap: CFMachPort?
var runLoopSource: CFRunLoopSource?

// CGEventTap 콜백 함수
func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .keyDown || type == .flagsChanged {
        // 현재 활성화된 앱 이름을 가져옴
        let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        
        // RDP가 활성화된 경우에만 지정키 차단
        if activeApp == "Microsoft Remote Desktop" {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags.rawValue
            
            // Command + Space (keyCode 49 = Space)
            if flags & CGEventFlags.maskCommand.rawValue != 0 && keyCode == 49 {
                print("Command + Space 키 차단함 (RDP 실행중일때만)")
                return nil  // 이벤트 무시
            }
            
            // Control + Space (keyCode 49 = Space)
            if flags & CGEventFlags.maskControl.rawValue != 0 && keyCode == 49 {
                print("Control + Space 키 차단함 (RDP 실행중일때만)")
                return nil  // 이벤트 무시
            }
        }
    }
    
    return Unmanaged.passUnretained(event)  // 이벤트 통과
}

// Event Tap 시작 함수
func startEventTap() {
    let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
    
    eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                 place: .headInsertEventTap,
                                 options: .defaultTap,
                                 eventsOfInterest: CGEventMask(eventMask),
                                 callback: eventTapCallback,
                                 userInfo: nil)
    
    if let eventTap = eventTap {
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("이벤트 생성 성공!!")
    } else {
        print("이벤트 생성 실패 ㅜㅜ 손쉬운 사용에 app추가 필요")
    }
}


// Event Tap 중지 함수
func stopEventTap() {
    if let eventTap = eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: false)
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        print("이벤트 중단")
    }
}

