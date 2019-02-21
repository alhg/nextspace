/* -*- mode: objc -*- */
/*
      Project: SoundKit framework.

  Description: NXSoundOut is the one of the final link in chain:
               NXSoundServer <- NXSoundDevice |-> NXSoundOut
               NXSoundOut has acces to own device (Sink) and inherited from 
               NXSoundDevice (Server and Card). NXSoundOut is enough if your
               application will read info about sound output as well as change 
               sound device properties (volume, balance, mute, profile, port).
               To play sound you also need NXSoundStream connected to NXSounOut.
               (see NXSoundStream description).

  Copyright (C) 2019 Sergii Stoian

  This application is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This application is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this library; if not, write to the Free
  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "PACard.h"
#import "PASink.h"
#import "NXSoundOut.h"

@implementation NXSoundOut

- (void)dealloc
{
  NSLog(@"[NXSoundOut] dealloc");
  [_sink release];
  [super dealloc];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"PulseAudio Sink `%@`", _sink.description];
}

// For debuging purposes
- (void)printDescription
{
  fprintf(stderr, "+++ NXSoundDevice: %s +++\n", [[super description] cString]);
  [super printDescription];
  
  fprintf(stderr, "+++ NXSoundOut: %s +++\n", [[self description] cString]);
  fprintf(stderr, "\t               Sink : %s (%lu)\n",  [_sink.name cString],
          [_sink retainCount]);
  fprintf(stderr, "\t   Sink Description : %s\n",  [_sink.description cString]);
  fprintf(stderr, "\t        Active Port : %s\n",  [_sink.activePort cString]);
  fprintf(stderr, "\t         Card Index : %lu\n", _sink.cardIndex);
  fprintf(stderr, "\t       Card Profile : %s\n",  [super.card.activeProfile cString]);
  fprintf(stderr, "\t       Retain Count : %lu\n", [self retainCount]);

  fprintf(stderr, "\t    Available Ports : \n");
  for (NSString *port in [self availablePorts]) {
    NSString *portString;
    if ([port isEqualToString:_sink.activePort])
      portString = [NSString stringWithFormat:@"%s%@%s", "\e[1m- ", port, "\e[0m"];
    else
      portString = [NSString stringWithFormat:@"%s%@%s", "- ", port, ""];
    fprintf(stderr, "\t                    %s\n", [portString cString]);
  }
}

/*--- Sink proxy ---*/
- (NSArray *)availablePorts
{
  if (_sink == nil) {
    NSLog(@"SKSoundOut: avaliablePorts was called without Sink was being set.");
    return nil;
  }
  return _sink.ports;
}
- (NSString *)activePort
{
  return _sink.activePort;
}
- (void)setActivePort:(NSString *)portName
{
}

@end
