//
//  Game.h
//  liar
//
//  Created by Scott Nielsen on 1/18/11.
//  Copyright 2011 Scott Nielsen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "GCDAsyncSocket.h"

@class Player;

@interface Game : NSObject <GCDAsyncSocketDelegate> {
    long nextTag;
    
    BOOL started;
    BOOL startMsgSent;
    NSMutableArray *players;
    NSMutableArray *waiters;
    
    int totalDice;
    int currentPlayer;
    int lastPlayer;
    int currentBidCount;
    int currentBidValue;
    
    dispatch_source_t timeout;
}

@property (readonly) BOOL started;

- (Player *)playerForConnection:(int)conn fromPlayer:(Player *)player;
- (int)connectionForPlayer:(Player *)player fromPlayer:(Player *)requestor;
- (NSArray *)allPlayersFromPlayer:(Player *)player;
- (NSArray *)currentTurnFromPlayer:(Player *)player;
- (void)playerDidDisconnect:(Player *)player;
- (void)sendChat:(NSString *)message fromPlayer:(Player *)player;
- (void)playerIsReady:(Player *)player;
- (BOOL)bidCount:(int)count value:(int)value fromPlayer:(Player *)player;
- (BOOL)challengeFromPlayer:(Player *)player;

@end
