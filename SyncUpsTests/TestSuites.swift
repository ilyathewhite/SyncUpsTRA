//
//  TestSuites.swift
//  SyncUps
//
//  Created by Ilya Belenkiy on 2/16/26.
//

import Testing

@Suite
struct ModelTests {}

@Suite(.serialized)
struct EventTests {
    @Suite @MainActor struct UserEventTests {}
    @Suite @MainActor struct OverlayTests {}
    @Suite @MainActor struct IntegrationTests {}
}

@Suite @MainActor struct NavigationTests {}
