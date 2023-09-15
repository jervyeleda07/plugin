//
//  LBProfilingConnections.h
//  LemonBank
//
//  Copyright © 2020 ThreatMetrix. All rights reserved.
//

#ifndef LBProfilingConnections_h
#define LBProfilingConnections_h

#import <Foundation/Foundation.h>
#import "TMXProfilingConnectionsProtocol.h"

/*!
 * This is a simple example of implementing an interface that conforms to TMXProfilingConnectionsProtocol
 * This example doesn't offer any additional feature such as configuring connection timeout, etc.
 */
@interface LBProfilingConnections : NSObject<TMXProfilingConnectionsProtocol>

@end

#endif /* LBProfilingConnections_h */
