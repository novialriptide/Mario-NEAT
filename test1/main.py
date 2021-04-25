import math
import sys
import random
import operator
import pygame
import gamedenRE as engine
from gene_algor import *

SCREEN_SIZE = [1000, 1000]

tilemap = generate_tilemap(50,50)
print_tilemap(tilemap)

beginning_x = int(input("X Start: "))
beginning_y = int(input("Y Start: "))

target_x = int(input("X Target: "))
target_y = int(input("Y Target: "))

pygame.init()
clock = pygame.time.Clock()
screen = pygame.display.set_mode(SCREEN_SIZE)
ts_data = [(122,122,122),(233,233,233),(255,255,255)]
ts = engine.tileset2(ts_data, (10,10))
tm_contents_default = engine.genereate_tilemap(1,1)
tm_contents_default["contents"][0] = tilemap
tm_contents = tm_contents_default
tm = engine.tilemap(tm_contents, tileset=ts)
tm.get_collision_rects((0,0), 0)

population = []
generation = 1
isActive = True
children_per_gen = 100
while(True):
    left_mouse_click_up = False
    right_mouse_click = False
    mouse_pos = pygame.mouse.get_pos()
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()
        if event.type == pygame.MOUSEBUTTONUP:
            if event.button == 1:
                left_mouse_click_up = True

    screen.fill((0,0,0))
    screen.blit(tm.get_image_map(), (0,0))
    print(f"#################### GENERATION #{generation} ####################")
    for person_id in range(children_per_gen):
        e = engine.entity2(pygame.Rect(0,0,10,10), map_class=tm)
        print(f"g:{generation} p:{person_id}")
        #print(f"ID: {person_id}")
        p = person(beginning_x, beginning_y, tilemap, target_x, target_y)
        generate_random_moveset(p)
        #draw_all_moves(p, beginning_x, beginning_y)
        population.append(p)
        for move in p.moveset:
            current_x = beginning_x+move.mx
            current_y = beginning_y+move.my
            #print(current_x*ts.tile_size[0], current_y*ts.tile_size[1])
            e.move((move.mx, move.my), obey_collisions=True)
            #print(f"x:{current_x} y:{current_y}")
            if current_x == p.target_x and current_y == p.target_y:
                p.fitness_points += 300
                p.purpose_achieved = True
                print(f"Found a solution for id:{person_id} in generation:{generation}")
                break
        #tm.map_data = tm_contents_default
    pygame.display.update()

    sorted_population = sorted(population, key=operator.attrgetter("fitness_points"))

    population = crossover(sorted_population[-1], sorted_population[-2], int(children_per_gen*0.7))
    population.extend(mutate(sorted_population[-1], int(children_per_gen*0.3)))
    generation += 1
    clock.tick(60)