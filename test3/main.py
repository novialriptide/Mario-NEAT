from ai import *
import pygame

pygame.init()

d = dot()
x = 0
y = 0
for _dir in d.directions:
    x += _dir.x
    y += _dir.y
    print(x, y)
    
d.mutate()
x = 0
y = 0
for _dir in d.directions:
    x += _dir.x
    y += _dir.y
    print(x, y)