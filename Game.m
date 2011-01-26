//
//  Game.m
//  liar
//
//  Created by Scott Nielsen on 1/18/11.
//  Copyright 2011 Scott Nielsen. All rights reserved.
//

#import "Game.h"
#import "Player.h"


@interface Game (Private)

- (int)connectionForIndex:(int)index fromIndex:(int)base;
- (int)indexForConnection:(int)conn fromIndex:(int)base;
- (void)start;
- (void)sendStartMessage;
- (void)nextTurn;
- (BOOL)isValidBidCount:(int)count value:(int)value;
- (int)countOfDiceWithValue:(int)value;
- (void)showResultsFromChallenger:(Player *)player;
- (void)resetRoundNextPlayer:(int)player;

@end

@implementation Game

@synthesize started;

- (id)init {
    if (self = [super init]) {
        nextTag = 0;
        players = [[NSMutableArray alloc] init];
        waiters = [[NSMutableArray alloc] init];
        
        timeout = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                         0, 0, dispatch_get_main_queue());
        
    }
    return self;
}

- (void)dealloc {
    [players release];
    [waiters release];
    [super dealloc];
}

- (void)start {
    totalDice = 0;
    // Remove players who are not ready
    for (Player *p in players) {
        if (!p.ready) {
            [waiters addObject:p];
        }
    }
    for (Player *p in waiters) {
        [players removeObject:p];
    }
    // Send name commands to each player for each player
    for (Player *p in players) {
        int base = [players indexOfObject:p];
        for (Player *q in players) {
            int index = [players indexOfObject:q];
            int conn = [self connectionForIndex:index fromIndex:base];
            [p sendNameWithConnection:conn player:q];
        }
        // Each gets 5 dice and rolls
        totalDice += 5;
        [p resetDice];
        [p roll];
    }
    currentPlayer = rand() % [players count];
    [[players objectAtIndex:currentPlayer] yourTurn];
    started = TRUE;
}

- (void)reset {
    started = FALSE;
    startMsgSent = FALSE;
    totalDice = 0;
    currentPlayer = 0;
    lastPlayer = 0;
    currentBidCount = 0;
    currentBidValue = 0;
    for (Player *p in waiters) {
        [players addObject:p];
    }
    [waiters release];
    waiters = [[NSMutableArray alloc] init];
    for (Player *p in players) {
        p.ready = FALSE;
    }
}

- (int)connectionForIndex:(int)index fromIndex:(int)base {
    if (index < base) {
        index += [players count];
    }
    return index - base + 1;
}

- (int)indexForConnection:(int)conn fromIndex:(int)base {
    return (base + conn - 1) % [players count];
}

- (Player *)playerForConnection:(int)conn fromPlayer:(Player *)player {
    int base = [players indexOfObject:player];
    int index = [self indexForConnection:conn fromIndex:base];
    return [players objectAtIndex:index];
}

- (int)connectionForPlayer:(Player *)player fromPlayer:(Player *)requestor {
    int base = [players indexOfObject:requestor];
    int index = [players indexOfObject:player];
    return [self connectionForIndex:index fromIndex:base];
}
    
- (NSArray *)allPlayersFromPlayer:(Player *)player {
    int base = [players indexOfObject:player];
    NSMutableArray *list = [[[NSMutableArray alloc] initWithCapacity:[players count]] autorelease];
    for(Player *p in players) {
        int i = [players indexOfObject:p];
        NSNumber *conn = [NSNumber numberWithInt:[self connectionForIndex:i fromIndex:base]];
        NSArray *a = [NSArray arrayWithObjects:conn, p, nil];
        [list addObject:a];
    }
    return list;
}

- (NSArray *)currentTurnFromPlayer:(Player *)player {
    int base = [players indexOfObject:player];
    int index = currentPlayer;
    NSNumber *conn = [NSNumber numberWithInt:[self connectionForIndex:index fromIndex:base]];
    return [NSArray arrayWithObjects:conn, [players objectAtIndex:currentPlayer], nil];
}

- (void)playerDidDisconnect:(Player *)player {
    if ([waiters containsObject:player]) {
        [waiters removeObject:player];
        return;
    }
    if ([players containsObject:player]) {
        if (!self.started || [player.dice count] == 0) {
            [players removeObject:player];
            return;
        }
        // If we made it this far then someone has disconnected with dice
        // TODO: How should this be handled?
    }
}

- (void)sendChat:(NSString *)message fromPlayer:(Player *)player {
    for(Player *p in players) {
        if (![p isEqual:player]) {
            [p sendChat:message fromPlayer:player];
        }
    }
}

- (void)playerIsReady:(Player *)player {
    if ([players count] < 2) return;
    int playersReady = 0;
    for(Player *p in players) {
        if (p.ready) playersReady++;
    }
    if (playersReady > 1) {
        if (!startMsgSent) [self sendStartMessage];
        if (playersReady == [players count]) [self start];
    }
}

- (void)sendStartMessage {
    startMsgSent = TRUE;
    for (Player *p in players) {
        [p sendStartMessage];
    }
    dispatch_time_t fifteen = dispatch_time(DISPATCH_TIME_NOW, 15.0 * NSEC_PER_SEC);
    dispatch_after(fifteen, dispatch_get_main_queue(), ^{
        if (!self.started) {
            [self start];
        }
    });
}

- (void)nextTurn {
    lastPlayer = currentPlayer;
    while (TRUE) {
        currentPlayer = (currentPlayer + 1) % [players count];
        if ([[[players objectAtIndex:currentPlayer] dice] count] > 0) break;
    }
    [[players objectAtIndex:currentPlayer] yourTurn];
}

- (BOOL)isValidBidCount:(int)count value:(int)value {
    if (value < 1 || 6 < value) return FALSE;
    int _count = count;
    int _currentBidCount = currentBidCount;
    if (value == 1) _count *= 2;
    if (currentBidValue == 1) _currentBidCount *= 2;
    if (_count < _currentBidCount) return FALSE;
    if (_count == _currentBidCount && value <= currentBidValue) return FALSE;
    return TRUE;
}    

- (BOOL)bidCount:(int)count value:(int)value fromPlayer:(Player *)player {
    if (![[players objectAtIndex:currentPlayer] isEqual:player]) return FALSE;
    if (![self isValidBidCount:count value:value]) return FALSE;
    currentBidCount = count;
    currentBidValue = value;
    for (Player *p in players) {
        if (![p isEqual:player]) {
            [p sendBidCount:count value:value fromPlayer:player];
        }
    }
    [self nextTurn];
    return TRUE;
}

- (BOOL)challengeFromPlayer:(Player *)player {
    if(![[players objectAtIndex:currentPlayer] isEqual:player]) return FALSE;
    if(currentBidCount == 0) return FALSE;
    [self showResultsFromChallenger:player];
    int nextPlayer = -1;
    int diff = currentBidCount - [self countOfDiceWithValue:currentBidValue];
    if (diff > 0) {
        [[players objectAtIndex:lastPlayer] loseDice:diff];
        for (Player *p in players) {
            [p sendLoseDice:diff fromPlayer:[players objectAtIndex:lastPlayer]];
        }
        nextPlayer = lastPlayer;
    }
    else if (diff == 0) {
        for (Player *p in players) {
            if (![p isEqual:[players objectAtIndex:lastPlayer]]) {
                [p loseDice:1];
            }
            [p sendLoseDiceAllExceptPlayer:[players objectAtIndex:lastPlayer]];
        }
        nextPlayer = currentPlayer;
    }
    else if (diff < 0) {
        [[players objectAtIndex:currentPlayer] loseDice:abs(diff)];
        for (Player *p in players) {
            [p sendLoseDice:abs(diff) fromPlayer:[players objectAtIndex:currentPlayer]];
        }
        nextPlayer = currentPlayer;
    }
    [self resetRoundNextPlayer:nextPlayer];
    return TRUE;
}

- (int)countOfDiceWithValue:(int)value {
    int count = 0;
    for (Player *p in players) {
        for (NSNumber *die in p.dice) {
            if ([die intValue] == value || [die intValue] == 1) count++;
        }
    }
    return count;
}

- (void)showResultsFromChallenger:(Player *)player {
    for (Player *p in players) {
        if (![p isEqual:player]) [p sendChallengeFromPlayer:player];
        for(Player *q in players) {
            if (![p isEqual:q]) [p sendResultForPlayer:q];
        }
    }
}

- (void)resetRoundNextPlayer:(int)player {
    NSMutableArray *hasDice = [NSMutableArray arrayWithCapacity:1];
    for (Player *p in players) {
        if ([p.dice count] > 0) [hasDice addObject:p];
    }
    if ([hasDice count] == 1) {
        for (Player *p in players) {
            [p sendWinner:[hasDice objectAtIndex:0]];
        }
        [self reset];
    }
    else {
        currentBidCount = 0;
        currentBidValue = 0;
        currentPlayer = player;
        for (Player *p in players) [p roll];
        if ([[[players objectAtIndex:currentPlayer] dice] count] == 0) [self nextTurn];
        else [[players objectAtIndex:currentPlayer] yourTurn];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// MARK: -
// MARK: Async Socket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
    Player *player = [[Player alloc] initWithSocket:newSocket tag:nextTag++];
    player.game = self;
    if (self.started) {
        [waiters addObject:player];
    }
    else {
        [players addObject:player];
    }
    [player release];
}

@end
