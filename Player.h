//
//  Player.h
//  liar
//
//  Created by Scott Nielsen on 1/18/11.
//  Copyright 2011 Scott Nielsen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "Game.h"


@interface Player : NSObject <GCDAsyncSocketDelegate> {
    GCDAsyncSocket *socket;
    long _tag;
    
    NSString *name;
    Game *game;
    BOOL ready;
    BOOL connected;
    
    int dice_count;
    NSArray *dice;
}

@property (assign) long tag;
@property (retain) NSString *name;
@property (retain) Game *game;
@property (assign) BOOL ready;
@property (assign) BOOL connected;
@property (retain) NSArray *dice;

- (id)initWithSocket:(GCDAsyncSocket *)sock tag:(long)tag;
- (void)write:(NSString *)msg;
- (void)sendChat:(NSString *)message fromPlayer:(Player *)player;
- (void)sendNameWithConnection:(int)conn player:(Player *)player;
- (void)sendStartMessage;
- (void)sendBidCount:(int)count value:(int)value fromPlayer:(Player *)player;
- (void)sendChallengeFromPlayer:(Player *)player;
- (void)sendLoseDice:(int)count fromPlayer:(Player *)player;
- (void)sendLoseDiceAllExceptPlayer:(Player *)player;
- (void)sendResultForPlayer:(Player *)player;
- (void)sendWinner:(Player *)player;
- (void)resetDice;
- (void)loseDice:(int)lost;
- (void)roll;
- (void)yourTurn;

@end
