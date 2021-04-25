import gamedenRE as engine
import pygame
import sys
import random
import math
import operator
"""
Dots needs to go to food to eat
"""

SCREEN_SIZE = [500, 500]

class point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

class dot:
    def __init__(self, start: point, end: point):
        self.origin_start = start
        self.start = start
        self.end = end
        self.speed = 10
        self.fitness_points = 0
        self.is_alive = True
        self.rgb = (255,255,255)
        self.directions = []
        self.max_directions = 200

        self.entity = engine.entity2(pygame.Rect(self.start.x, self.start.y, 5, 5))

        self.randomize_moves()

    def draw(self, surface):
        pygame.draw.rect(surface, self.rgb, self.entity.rect)

    def randomize_moves(self):
        for d in range(self.max_directions):
            rads = math.radians(random.randint(0, 360))
            p = point(math.cos(rads) * self.speed, math.sin(rads) * self.speed)
            self.entity.move((p.x, p.y))
            self.directions.append(p)

    def copy(self):
        d = dot(self.start, self.end)
        d.speed = self.speed
        d.fitness_points = self.fitness_points
        d.is_alive = self.is_alive
        d.rgb = self.rgb
        d.directions = self.directions
        d.max_directions = self.max_directions

    def mutate(self):
        mutation_rate = 0.001
        for d in range(len(self.directions)):
            chance = random.uniform(0, 1)
            if (chance < mutation_rate):
                rads = math.radians(random.randint(0, 360))
                p = point(math.cos(rads) * self.speed, math.sin(rads) * self.speed)
                self.directions[d] = p
    
    @property
    def distance_from_end(self):
        #print(self.entity.rect.x, self.entity.rect.y)
        return math.sqrt(abs(self.entity.rect.x-self.end.x)^2 + abs(self.entity.rect.y-self.end.y)^2)
    
    def update(self):
        if 0 > self.entity.rect.x and SCREEN_SIZE[0] < self.entity.rect.x and 0 > self.entity.rect.y and SCREEN_SIZE[1] < self.entity.rect.y:
            self.is_alive = False

    def execute_moveset(self):
        self.start = self.origin_start
        self.entity.x = self.origin_start.x
        self.entity.y = self.origin_start.y
        for d in self.directions:
            self.entity.move((d.x, d.y))

class population:
    def __init__(self, population_number: int, default_speed: float):
        self.original_population_number = population_number
        self.dots = []
        for d in range(population_number):
            start_pos = point(0, 0)
            end_pos = point(350, 350)
            self.dots.append(dot(start_pos, end_pos))
        self.food = []
        self.generation = 0

    def find_best_fitness(self):
        sorted_dots = sorted(self.dots, key=operator.attrgetter("distance_from_end"))
        return sorted_dots[0]
    
    def flood_population_with_clones(self, dot: dot):
        self.dots = []
        for d in range(self.original_population_number):
            self.dots.append(dot)

    def mutate_everything(self):
        for d in self.dots:
            d.mutate()
    
    def update_moves_everything(self):
        for d in self.dots:
            d.execute_moveset()

    def draw_everything(self, surface):
        for d in self.dots:
            d.draw(surface)
        
        for f in self.food:
            f.draw(surface)

pygame.init()
screen = pygame.display.set_mode(SCREEN_SIZE)

p = population(50, 10)
screen.fill((0,0,0))
while(True):
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()
    #screen.fill((0,0,0))
    #p.draw_everything(screen)
    best = p.find_best_fitness()
    p.flood_population_with_clones(best)
    p.mutate_everything()
    p.update_moves_everything()

    for d in p.dots:
        d.update()

    pygame.draw.rect(screen, (255,255,255), pygame.Rect(350, 350, 10, 10))
    pygame.draw.rect(screen, (255,255,255), best.entity.rect)

    pygame.display.update()