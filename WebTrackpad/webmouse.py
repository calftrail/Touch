#! /usr/bin/python

# Written by Nathan Vander Wilt. (c) 2009 Calf Trail Software, LLC

from Quartz import *
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
import cgi, urlparse
import time

def tl_uptime():
	return 0;
	#return NSDate.date().timeIntervalSinceReferenceDate() * 1e9;
	#return NSProcessInfo.processInfo().systemUptime()

class TrackPadServer (BaseHTTPRequestHandler):
	def do_GET(self):
		self.send_response(200)
		self.send_header('Content-type', 'text/html')
		self.end_headers()
		
		f = open('sender.html')
		self.wfile.write(f.read())
	
	def do_POST(self):
		self.send_response(204)
		self.end_headers()
		
		d = cgi.parse_qs(urlparse.urlsplit(self.path).query)
		eventInfo = {}
		for key, val in sorted(d.iteritems()):
			eventInfo[key] = float(val[0]);
		
		if 'dX' in eventInfo and 'dY' in eventInfo:
			protoEvent = CGEventCreate(None)
			pos = CGEventGetLocation(protoEvent)
			pos.x += eventInfo['dX']
			pos.y += eventInfo['dY']
			e = CGEventCreateMouseEvent(None, kCGEventMouseMoved, pos, 0)
			CGEventPost(kCGHIDEventTap, e)
		elif 'dScale' in eventInfo:
			mag = eventInfo['dScale']
			delay = 0.05
			
			e = CGEventCreate(None)
			CGEventSetType(e, 0x1D)
			CGEventSetFlags(e, 0x100)
			
			CGEventSetTimestamp(e, tl_uptime())
			CGEventSetIntegerValueField(e, 0x6E, 0x3D)
			CGEventSetIntegerValueField(e, 0x75, 0x08)
			CGEventPost(kCGHIDEventTap, e)
			time.sleep(delay)
			
			CGEventSetTimestamp(e, tl_uptime())
			CGEventSetIntegerValueField(e, 0x6E, 0x08)
			CGEventSetDoubleValueField(e, 0x71, 0.00)
			CGEventPost(kCGHIDEventTap, e)
			time.sleep(delay)
			
			CGEventSetTimestamp(e, tl_uptime())
			CGEventSetIntegerValueField(e, 0x6E, 0x08)
			CGEventSetDoubleValueField(e, 0x71, mag)
			CGEventPost(kCGHIDEventTap, e)
			time.sleep(delay)
			
			CGEventSetTimestamp(e, tl_uptime())
			CGEventSetIntegerValueField(e, 0x6E, 0x3E)
			CGEventSetIntegerValueField(e, 0x75, 0)
			CGEventPost(kCGHIDEventTap, e)

webServer = HTTPServer(('', 8080), TrackPadServer)
webServer.serve_forever()
