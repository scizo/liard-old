//
//  GameTestCase.m
//  liar
//
//  Created by Scott Nielsen on 1/17/11.
//  Copyright 2011 Scott Nielsen. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <dispatch/dispatch.h>
#import "Game.h"


@interface GameTestCase : SenTestCase {
    Game *game;
}

@end

@implementation GameTestCase

- (void)setUp {
    game = [[Game alloc] init];
}

- (void)tearDown {
    [game release];
}

- (void)testInitReturnsAGameObject {
    NSString *msg = @"game should be an object with class Game";
    STAssertTrue([game isKindOfClass:[Game class]], msg);
}

- (void)testStartedBeginsFalse {
    NSString *msg = @"fresh game hasn't been started";
    STAssertFalse(game.started, msg);
}

@end
