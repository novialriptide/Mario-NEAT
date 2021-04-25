from ai import *
import pygame
import sys

SCREEN_SIZE = point(750, 750)
START = point(SCREEN_SIZE.x/2, SCREEN_SIZE.y/2)
END = point(SCREEN_SIZE.x/2, SCREEN_SIZE.y-50)

pygame.init()
clock = pygame.time.Clock()
screen = pygame.display.set_mode((SCREEN_SIZE.x, SCREEN_SIZE.y))

p = population(100, START, END, SCREEN_SIZE)
screen.fill((0,0,0))
while(True):
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()

    screen.fill((0,0,0))
    p.draw(screen)
    pygame.draw.circle(screen, (255,255,255), (END.x, END.y), 5)
    p.new_generation()
    #print("d")

    clock.tick(1)
    pygame.display.update()