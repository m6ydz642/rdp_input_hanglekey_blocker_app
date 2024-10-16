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

// Control + Space 키 입력을 RDP로 직접 전달하는 함수
func sendControlSpaceToRDP() {
    // Control 키 down (Control keyCode = 0x3B)
    let controlKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x3B, keyDown: true)
    controlKeyDown?.flags = .maskControl
    controlKeyDown?.post(tap: .cgAnnotatedSessionEventTap)  // 세션에 이벤트 전송
    
    usleep(100_000)  // 100ms 딜레이 (이벤트 처리 간의 시간 차이)

    // Space 키 down (Space keyCode = 49)
    let spaceKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)
    spaceKeyDown?.flags = .maskControl  // 유지된 Control modifier flag
    spaceKeyDown?.post(tap: .cgAnnotatedSessionEventTap)

    // Space 키 up
    let spaceKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)
    spaceKeyUp?.flags = .maskControl
    spaceKeyUp?.post(tap: .cgAnnotatedSessionEventTap)

    // Control 키 up (Control keyCode = 0x3B)
    let controlKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x3B, keyDown: false)
    controlKeyUp?.flags = .maskControl
    controlKeyUp?.post(tap: .cgAnnotatedSessionEventTap)
}


// Control 키만 따로 처리하여 RDP로 전달
func sendControlKeyToRDP() {
    // Control 키 down (Control keyCode = 0x3B)
    let controlKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x3B, keyDown: true)
    controlKeyDown?.flags = .maskControl
    controlKeyDown?.post(tap: .cgAnnotatedSessionEventTap)  // 세션에 이벤트 전송
    
    usleep(100_000)  // 100ms 딜레이 (이벤트 처리 간의 시간 차이)
    
    // Control 키 up
    let controlKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x3B, keyDown: false)
    controlKeyUp?.flags = .maskControl
    controlKeyUp?.post(tap: .cgAnnotatedSessionEventTap)
}

// Space 키만 따로 처리하여 RDP로 전달
func sendSpaceKeyToRDP() {
    // Space 키 down (Space keyCode = 49)
    let spaceKeyDown = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)
    spaceKeyDown?.post(tap: .cgAnnotatedSessionEventTap)

    // Space 키 up
    let spaceKeyUp = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)
    spaceKeyUp?.post(tap: .cgAnnotatedSessionEventTap)
}


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
                // 커맨드 제어는 다음에
                return nil  // 이벤트 무시
            }
            
            // Control + Space (keyCode 49 = Space)
            if flags & CGEventFlags.maskControl.rawValue != 0 && keyCode == 49 {
                print("Control + Space 키 차단함 (RDP 실행중일때만)")
                handleKeyEvent(event: event)
                return nil  // 이벤트 무시
            }
        }
    }
    
    return Unmanaged.passUnretained(event)  // 이벤트 통과
}
// 키 이벤트를 처리하는 함수
func handleKeyEvent(event: CGEvent) {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    
    // Control + Space 키 조합 감지
    if flags.contains(.maskControl) && keyCode == 49 {  // Space의 keyCode는 49
        print("Control + Space detected")
       // sendControlSpaceToRDP()  // RDP로 키 전달
        print("Control + Space detected")
               sendControlKeyToRDP()  // Control 키 전송
               usleep(100_000)        // 약간의 딜레이 추가
               sendSpaceKeyToRDP()    // Space 키 전송
    }
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
    // 이벤트 탭 설정
    let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
    // 콜백 이벤트 추가
    if let eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: eventMask, callback: eventTapCallback, userInfo: nil) {
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        CFRunLoopRun()
        print("이벤트 생성 성공")
    } else {
        print("이벤트 생성 실패")
    }
}

