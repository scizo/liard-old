//
//  Player.m
//  liar
//
//  Created by Scott Nielsen on 1/18/11.
//  Copyright 2011 Scott Nielsen. All rights reserved.
//

#import "Player.h"


@interface Player (Private)

- (SEL)selectorForCommand:(NSString *)command;
- (void)read;

- (void)bid:(NSArray *)args;
- (void)challenge:(NSArray *)args;
- (void)chat:(NSArray *)args;
- (void)help:(NSArray *)args;
- (void)ready:(NSArray *)args;
- (void)setname:(NSArray *)args;
- (void)unready:(NSArray *)args;
- (void)who:(NSArray *)args;
- (void)whoseturn:(NSArray *)args;

- (void)sendCurrentTurnWithConnection:(int)conn player:(Player *)player;
- (void)sendRoll;

@end

@implementation Player

@synthesize tag=_tag, name, game, ready, dice, connected;

- (id)initWithSocket:(GCDAsyncSocket *)sock tag:(long)tag {
    if (self = [super init]) {
        socket = [sock retain];
        socket.delegate = self;
        _tag = tag;
        self.connected = YES;
        dice_count = 0;
        self.dice = [NSArray array];
        [self read];
    }
    return self;
}

- (void)dealloc {
    [socket release];
    [name release];
    [dice release];
    [super dealloc];
}

- (SEL)selectorForCommand:(NSString *)command {
    return NSSelectorFromString([NSString stringWithFormat:@"%@:", command]);
}

- (void)resetDice {
    dice_count = 5;
}

- (void)loseDice:(int)lost {
    dice_count -= lost;
    if (dice_count < 1) {
        dice_count = 0;
        self.dice = [NSArray array];
    }
}

- (void)roll {
    NSNumber *roll[dice_count];
    for (int i = 0; i < dice_count; i++) {
        int tmp = (rand() % 6) + 1;
        roll[i] = [NSNumber numberWithInt:tmp];
    }
    self.dice = [NSArray arrayWithObjects:roll count:dice_count];
    [self sendRoll];
}

- (void)yourTurn {
    [self sendCurrentTurnWithConnection:1 player:self];
}

- (void)read {
    [socket readDataToData:[GCDAsyncSocket LFData] withTimeout:-1 tag:_tag];
}

- (void)write:(NSString *)msg {
    NSString *s = [NSString stringWithFormat:@"%@\r\n", msg];
    NSData *data = [s dataUsingEncoding:NSUTF8StringEncoding];
    [socket writeData:data withTimeout:-1 tag:_tag];
}

- (void)error:(NSString *)msg {
    [self write:[NSString stringWithFormat:@"CHAT <host> %@", msg]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// MARK: -
// MARK: AsyncSocket Delegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)_tag {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *cs = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([cs length] == 0) {
        [self read];
        [message release];
        [pool drain];
        return;
    }
    NSArray *ca = [cs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    SEL command = [self selectorForCommand:[[ca objectAtIndex:0] lowercaseString]];
    NSArray *args = [ca subarrayWithRange:NSMakeRange(1, [ca count] - 1)];
    if ([self respondsToSelector:command]) {
        [self performSelector:command withObject:args];
    }
    
    [self read];
                   
    [message release];
    [pool drain];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    self.connected = NO;
    [self.game playerDidDisconnect:(Player *)self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// MARK: -
// MARK: Command Methods
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)bid:(NSArray *)args {
    if (!self.name) {
        [self error:@"No commands can be entered before your name is set"];
        return;
    }
    BOOL success = [self.game bidCount:[[args objectAtIndex:0] intValue]
                                 value:[[args objectAtIndex:1] intValue]
                            fromPlayer:self];
    if (!success) [self error:@"Turn not accepted, try again!"];
}

- (void)challenge:(NSArray *)args {
    if (!self.name) {
        [self error:@"No commands can be entered before your name is set"];
        return;
    }
    BOOL success = [self.game challengeFromPlayer:self];
    if (!success) [self error:@"Turn not accepted, try again!"];
}

- (void)chat:(NSArray *)args {
    NSString *message = [args componentsJoinedByString:@" "];
    [self.game sendChat:message fromPlayer:self];
}

- (void)help:(NSArray *)args {
    NSString *helpmsg = @"\r\n\
    -- Commands from client\r\n\
\r\n\
    BID <num> <val>                                       Creates a bid of \"num vals (e.g. four 3's)\"\r\n\
    CHALLENGE                                             Challenges last bid (if one exists)\r\n\
    CHAT <msg>                                            Sends a message to all clients\r\n\
    HELP                                                  Lists these commands\r\n\
    READY                                                 Set client to ready for restart\r\n\
   *SETNAME <name>                                        Set (static) name to use. *Must be called before other commands and within 15 seconds of connecting.\r\n\
    UNREADY                                               Set client to \"not ready\" for restart\r\n\
    WHO [<connection #>]                                  Request a (list of) NAME response from server\r\n\
    WHOSETURN                                             Request a CURRENTTURN response from server\r\n\
\r\n\
    -- Commands from server\r\n\
\r\n\
    BID <connection #> <num> <val> <name>                 Indicates a bid from person # of \"num vals (eight 5's)\" from name\r\n\
    CHALLENGE <connection #> <name>                       Indicates a challenge from person #/name\r\n\
    CHAT <msg>                                            Indicates a chat message in this format: <name> message...\r\n\
    CURRENTTURN <connection #> <seconds> <name>           Indicates whose turn it is, turn timeout in seconds, and person's name\r\n\
    LOSEDICE <connection #> <dice> <name>                 Indicates that person # lost <dice> dice\r\n\
    LOSEDICEALL <except connection #>                     Indicates that all remaining persons, except one, lose one die each\r\n\
    NAME <connection #> <dice> <name>                     Declares a person's #, dice remaining, and name (static)\r\n\
    RESULT <connection #> <dice> <#> <[#]> <[etc.]>       Reveals another person's roll (after a challenge)\r\n\
    ROLL <numdice> <#> <[#]> <[#]> <[#]> <[#]> <[#]>      Your roll for the round\r\n\
    STARTING                                              Indicates a restart in 15 seconds or when all clients report ready (whichever occurs first)\r\n\
\r\n\
    Note: The client (you) is always connection #1.\r\n\
    This means it's your turn whenever you hear, \"CURRENTTURN 1 <time> <name>\"\r\n";
    
    [self write:helpmsg];
}
    
- (void)ready:(NSArray *)args {
    if (!self.name) {
        [self error:@"No commands can be entered before your name is set"];
        return;
    }
    if (self.game.started) {
        [self error:@"Can not ready while a game is in progress"];
        return;
    }
    self.ready = YES;
    [self.game playerIsReady:self];
}

- (void)setname:(NSArray *)args {
    if (self.name) {
        [self error:@"Name cannot be reset during a session"];
        return;
    }
    self.name = [args objectAtIndex:0];
}

- (void)unready:(NSArray *)args {
    if (!self.name) {
        [self error:@"No commands can be entered before your name is set"];
        return;
    }
    self.ready = NO;
}

- (void)who:(NSArray *)args {
    if (!self.name) {
        [self error:@"No commands can be entered before your name is set"];
        return;
    }
    if ([args count] > 0) {
        for(NSString *s in args) {
            int conn = [s intValue];
            Player *player = [self.game playerForConnection:conn fromPlayer:self];
            [self sendNameWithConnection:conn player:player];
        }
    }
    else {
        for(NSArray *a in [self.game allPlayersFromPlayer:self]) {
            [self sendNameWithConnection:[[a objectAtIndex:0] intValue]
                                  player:[a objectAtIndex:1]];
        }
    }
    
}

- (void)whoseturn:(NSArray *)args {
    if (!self.name) {
        [self error:@"No commands can be entered before your name is set"];
        return;
    }
    if (!game.started) {
        [self error:@"There is no current game"];
        return;
    }
    NSArray *a = [self.game currentTurnFromPlayer:self];
    [self sendCurrentTurnWithConnection:[[a objectAtIndex:0] intValue]
                                 player:[a objectAtIndex:1]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
// MARK: -
// MARK: Response Helpers
////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendNameWithConnection:(int)conn player:(Player *)player {
    NSString *msg = [NSString stringWithFormat:@"NAME %d %d %@",
                     conn, [player.dice count], player.name];
    [self write:msg];
}

- (void)sendCurrentTurnWithConnection:(int)conn player:(Player *)player {
    NSString *msg = [NSString stringWithFormat:@"CURRENTTURN %d %d %@",
                     conn, -1, player.name];
    [self write:msg];
}

- (void)sendChat:(NSString *)message fromPlayer:(Player *)player {
    NSString *msg = [NSString stringWithFormat:@"CHAT <%@> %@",
                     player.name, message];
    [self write:msg];
}

- (void)sendRoll {
    NSString *numbers = [self.dice componentsJoinedByString:@" "];
    NSString *msg = [NSString stringWithFormat:@"ROLL %d %@",
                     [self.dice count], numbers];
    [self write:msg];
}

- (void)sendStartMessage {
    [self write:@"STARTING"];
}

- (void)sendBidCount:(int)count value:(int)value fromPlayer:(Player *)player {
    int conn = [self.game connectionForPlayer:player fromPlayer:self];
    NSString *msg = [NSString stringWithFormat:@"BID %d %d %d %@",
                     conn, count, value, player.name];
    [self write:msg];
}

- (void)sendChallengeFromPlayer:(Player *)player {
    int conn = [self.game connectionForPlayer:player fromPlayer:self];
    NSString *msg = [NSString stringWithFormat:@"CHALLENGE %d %@",
                     conn, player.name];
    [self write:msg];
}

- (void)sendLoseDice:(int)count fromPlayer:(Player *)player {
    int conn = [self.game connectionForPlayer:player fromPlayer:self];
    NSString *msg = [NSString stringWithFormat:@"LOSEDICE %d %d %@",
                     conn, count, player.name];
    [self write:msg];
}

- (void)sendLoseDiceAllExceptPlayer:(Player *)player {
    int conn = [self.game connectionForPlayer:player fromPlayer:self];
    NSString *msg = [NSString stringWithFormat:@"LOSEDICEALL %d", conn];
    [self write:msg];
}

- (void)sendResultForPlayer:(Player *)player {
    int conn = [self.game connectionForPlayer:player fromPlayer:self];
    NSString *numbers = [player.dice componentsJoinedByString:@" "];
    NSString *msg = [NSString stringWithFormat:@"RESULT %d %d %@",
                     conn, [player.dice count], numbers];
    [self write:msg];
}

- (void)sendWinner:(Player *)player {
    int conn = [self.game connectionForPlayer:player fromPlayer:self];
    NSString *msg = [NSString stringWithFormat:@"WINNER %d %@",
                     conn, player.name];
    [self write:msg];
}

@end
