//
//  WPSPASTValueNode.m
//  WonderPush
//
//  Created by Stéphane JAIS on 26/06/2020.
//  Copyright © 2020 WonderPush. All rights reserved.
//

#import "WPSPASTValueNode.h"
#import "WPUtil.h"

@implementation WPSPASTValueNode

- (instancetype) initWithContext:(WPSPParsingContext *)context value:(id)value {
    if (self = [super init]) {
        _context = context;
        _value = value;
    }
    return self;
}

- (id) accept:(id<WPSPASTValueVisitor>)visitor {
    @throw @"abstract";
}

@end


@implementation WPSPASTUnknownValueNode;

- (instancetype) initWithContext:(WPSPParsingContext *)context key:(NSString *)key value:(id)value {
    if (self = [super initWithContext:context value:value]) {
        _key = key;
    }
    return self;
}

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitASTUnknownValueNode:self];
}

@end

@implementation WPSPNullValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitNullValueNode:self];
}

@end

@implementation WPSPBooleanValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitBooleanValueNode:self];
}

@end

@implementation WPSPNumberValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitNumberValueNode:self];
}

@end

@implementation WPSPStringValueNode;

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitStringValueNode:self];
}

@end

@implementation WPSPRelativeDateValueNode

- (instancetype)initWithContext:(WPSPParsingContext *)context duration:(WPSPISO8601Duration *)duration {
    if (self = [super initWithContext:context value:@0]) {
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithContext:(WPSPParsingContext *)context value:(id)value {
    @throw @"use initWithContext:duration:";
}

- (NSNumber *) value {
    NSDate *now = [NSDate dateWithTimeIntervalSince1970:([WPUtil getServerDate] / 1000.0)];
    return [NSNumber numberWithDouble:[self.duration applyTo:now].timeIntervalSince1970 * 1000];
}

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitRelativeDateValueNode:self];
}

@end

@implementation WPSPDateValueNode

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitDateValueNode:self];
}

@end

@implementation WPSPDurationValueNode

- (instancetype)initWithContext:(WPSPParsingContext *)context duration:(WPSPISO8601Duration *)duration {
    return [self initWithContext:context value:[self.class numberWithDuration:duration]];
}

+ (NSNumber *) numberWithDuration:(WPSPISO8601Duration *)duration {
    long long now = [WPUtil getServerDate];
    NSDate * nowDate = [NSDate dateWithTimeIntervalSince1970:(now / 1000.0)];
    long long then = [duration applyTo:nowDate].timeIntervalSince1970 * 1000.0;
    return [NSNumber numberWithLongLong:(then - now)];
}

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitDurationValueNode:self];
}

@end

@implementation WPSPGeoLocationValueNode

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitGeoLocationValueNode:self];
}

@end

@implementation WPSPGeoAbstractAreaValueNode
@end

@implementation WPSPGeoBoxValueNode

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitGeoBoxValueNode:self];
}

@end

@implementation WPSPGeoCircleValueNode

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitGeoCircleValueNode:self];
}

@end

@implementation WPSPGeoPolygonValueNode

- (id)accept:(id<WPSPASTValueVisitor>)visitor {
    return [visitor visitGeoPolygonValueNode:self];
}

@end
