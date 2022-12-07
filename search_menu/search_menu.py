#!/usr/bin/env python3

import os
import json
import sys
import pathlib


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
    for i in json_list:
        cmd = i.get('cmd')
        if cmd == None or cmd == "" or cmd == 'ignore':
            continue
        comment = i.get('comment')
        key = i.get('key')
        text = comment
        if text == None or text == "":
            text = cmd
        if mode == 'binding':
            text = text + " (" + key + ")"
        else:
            if text == cmd:
                text = text + " (" + key + ")"
            else:
                text = cmd + " (" + key + ") " + text
        if len(sys.argv) == 2 and sys.argv[1] == text:
            execute(cmd + "\n")
            break
        elif len(sys.argv) == 1:
            print(text)

def playlist():
    playlist_text = os.getenv('SEARCH_MENU_PLAYLIST')
    playlist_lines = playlist_text.splitlines()
    for x in range(0, len(playlist_lines)):
        text = pathlib.Path(playlist_lines[x]).name
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
