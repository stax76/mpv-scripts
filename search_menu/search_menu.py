#!/usr/bin/env python3

# https://github.com/stax76/mpv-scripts

import os
import json
import sys

class Binding:
    text = ""
    cmd = ""
    key = ""
    comment = ""
    priority = ""

def execute(cmd):
    if os.name == 'nt':
        import _winapi
        from multiprocessing.connection import PipeConnection
        socket_name = r"\\.\pipe\mpvsocket"
        access = _winapi.GENERIC_READ | _winapi.GENERIC_WRITE
        pipe_handle = _winapi.CreateFile(socket_name, access, 0, _winapi.NULL,
            _winapi.OPEN_EXISTING, _winapi.FILE_FLAG_OVERLAPPED, _winapi.NULL)
        pipe = PipeConnection(pipe_handle)
        pipe.send_bytes(cmd.encode('utf-8'))
        pipe.close()
    else:
        import socket
        socket_name = "/tmp/mpvsocket"
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(socket_name)
        client.send(cmd.encode('utf-8'))
        client.close()

def binding(mode):
    json_list = json.loads(os.getenv('SEARCH_MENU_BINDING'))
    binding_list = []
    for i in json_list:
        b = Binding()
        b.cmd = i.get('cmd')
        if b.cmd == None or b.cmd == "" or b.cmd == 'ignore':
            continue
        b.comment = i.get('comment')
        b.key = i.get('key')
        b.priority = i.get('priority')
        binding_list.append(b)
    for i in binding_list:
        for i2 in binding_list:
            if i.key == i2.key and i.priority < i2.priority:
                i.key = 'shadowed'
                break
    for b in binding_list:
        b.text = b.comment
        if b.text == None or b.text == "":
            b.text = b.cmd
        if mode == 'binding':
            b.text = b.text + " (" + b.key + ")"
        else:
            if b.text == b.cmd:
                b.text = b.text + " (" + b.key + ")"
            else:
                b.text = b.cmd + " (" + b.key + ") " + b.text
        if len(sys.argv) == 2 and sys.argv[1] == b.text:
            execute(b.cmd + "\n")
            break
        elif len(sys.argv) == 1:
            print(b.text)

def playlist():
    playlist_text = os.getenv('SEARCH_MENU_PLAYLIST')
    playlist_lines = playlist_text.splitlines()
    for x in range(0, len(playlist_lines)):
        text = os.path.basename(playlist_lines[x])
        if len(sys.argv) == 1:
            print(text)
        elif len(sys.argv) == 2 and sys.argv[1] == text:
            execute("no-osd set playlist-pos " + str(x) + "\n")
            break

def command():
    json_list = json.loads(os.getenv('SEARCH_MENU_COMMAND'))
    for cmd in json_list:
        text = cmd.get('name')
        if text == 'ignore':
            continue
        for arg in cmd.get('args'):
            name = arg.get('name')
            if arg.get('optional'):
                text = text + " [<" + name + ">]"
            else:
                text = text + " <" + name + ">"
        if len(sys.argv) == 1:
            print(text)
        elif len(sys.argv) == 2 and sys.argv[1] == text:
            execute("script-message-to search_menu search_menu-command '" + text + "'\n")
            break

def property():
    property_list = os.getenv('SEARCH_MENU_PROPERTY').split(",")
    for prop in property_list:
        if len(sys.argv) == 1:
            print(prop)
        elif len(sys.argv) == 2 and sys.argv[1] == prop:
            execute("script-message-to search_menu search_menu-property " + prop + "\n")
            break

def audio_track():
    tracks = os.getenv('SEARCH_MENU_AUDIO_TRACK').split("\\n")
    id = 0
    for i in tracks:
        if i.startswith("A: "):
            id = id + 1
            text = str(id) + ": " + i[3:]
            if len(sys.argv) == 1:
                print(text)
            elif len(sys.argv) == 2 and sys.argv[1] == text:
                execute("set aid " + str(id) + "\n")
                break

def sub_track():
    tracks = os.getenv('SEARCH_MENU_SUB_TRACK').split("\\n")
    id = 0
    for i in tracks:
        if i.startswith("S: "):
            id = id + 1
            text = str(id) + ": " + i[3:]
            if len(sys.argv) == 1:
                print(text)
            elif len(sys.argv) == 2 and sys.argv[1] == text:
                execute("set sid " + str(id) + "\n")
                break

mode = os.getenv('SEARCH_MENU_MODE')

if mode == 'binding' or mode == 'binding-full':
    binding(mode)
elif mode == 'playlist':
    playlist()
elif mode == 'command':
    command()
elif mode == 'property':
    property()
elif mode == 'audio-track':
    audio_track()
elif mode == 'sub-track':
    sub_track()
