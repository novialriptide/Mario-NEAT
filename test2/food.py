import gamedenRE as engine
import pygame
import sys
import random
"""
Dots needs to go to food to eat
"""

SCREEN_SIZE = [500, 500]

class point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

class dot:
    def __init__(self, start: point, speed: float):
        self.start = start
        self.speed = speed
        self.energy_remaining = 100 # acts as fitness points
        self.steps_taken = 0
        self.generation = 0
        self.chance_of_mutation = 0
        self.rgb = (255,255,255)

        self.entity = engine.entity2(pygame.Rect(self.start.x, self.start.y, 5, 5))

    def draw(self, surface):
        pygame.draw.rect(surface, self.rgb, self.entity.rect)

    def move(self, point):
        self.entity.move((self.point.x, self.point.y))

class food:
    def __init__(self, position: point, rgb: tuple, gives_energy: int):
        self.position = position
        self.rgb = rgb
        self.gives_energy = gives_energy
        
        self.entity = engine.entity2(pygame.Rect(self.position.x, self.position.y, 5, 5))

    def draw(self, surface):
        pygame.draw.rect(surface, self.rgb, self.entity.rect)

class population:
    def __init__(self, population_number: int, default_speed: float):
        self.original_population_number = population_number
        self.dots = []
        for d in range(population_number):
            start_pos = point(random.randint(0, SCREEN_SIZE[0]), random.randint(0, SCREEN_SIZE[1]))
            self.dots.append(dot(start_pos, default_speed*random.uniform(0.1, 1)))
        self.food = []
        self.energy_required_to_breed = 300
    
    def generate_food(self, amount: int):
        for f in range(amount):
            pos = point(random.randint(0, SCREEN_SIZE[0]), random.randint(0, SCREEN_SIZE[1]))
            food(pos, (255,0,0), 10)

    def draw_everything(self, surface):
        for d in self.dots:
            print(d.start.x, d.start.y)
            d.draw(surface)
        
        for f in self.food:
            f.draw(surface)

pygame.init()
screen = pygame.display.set_mode(SCREEN_SIZE)

p = population(50, 10)

while(True):
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()
    screen.fill((0,0,0))
    p.draw_everything(screen)

    pygame.display.update()