#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <time.h>
#import "Game.h"
#import "GCDAsyncSocket.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    srand(time(0));
    Game *game = [[Game alloc] init];
    
    dispatch_queue_t game_queue = dispatch_get_main_queue();
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:game delegateQueue:game_queue];
    
    NSUserDefaults *options = [NSUserDefaults standardUserDefaults];
    UInt16 port = [options integerForKey:@"port"];
    if (!port) {
        port = 35000;
    }
    
    NSError *err = NULL;
    
    if (![socket acceptOnPort:port error:&err]) {
        NSLog(@"accepting On port %d failed with error: %@", port, err);
        exit(1);
    }
    NSLog(@"listening on port %d", port);
    
    dispatch_main();
    
    [socket release];
    [game release];

    [pool drain];
    return 0;
}
