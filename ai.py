import pygame
import random
import math
import operator

class point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def clone(self):
        return point(self.x, self.y)
    
    def move(self, point):
        self.x += point.x
        self.y += point.y

    def to_string(self):
        return f"{self.x}, {self.y}"

class dot:
    def __init__(self, start: point, end: point, screen_size: point):
        self.current_draw_pos = start
        self.start_pos = start
        self.end_pos = end
        self.screen_size = screen_size
        self.directions = []
        self.max_directions = 100
        self.speed = 5
        self.randomize()

    def randomize(self):
        for i in range(self.max_directions):
            rads = math.radians(random.randint(0, 360))
            p = point(math.cos(rads) * self.speed, math.sin(rads) * self.speed)
            self.directions.append(p)

    def clone(self):
        d = dot(self.start_pos, self.end_pos, self.screen_size)
        d.directions = self.directions.copy()
        return d

    def mutate(self):
        for d in range(len(self.directions)):
            r = random.uniform(0, 1)
            if r < 0.01:
                rads = math.radians(random.randint(0, 360))
                direction = point(math.cos(rads) * self.speed, math.sin(rads) * self.speed)
                self.directions[d] = direction

    def draw(self, surface, rgb):
        pygame.draw.circle(surface, rgb, (self.end_point.x, self.end_point.y), 5)

    def move_to_end_point(self, direction):
        self.current_draw_pos.move(self.directions[direction])

    @property
    def end_point(self):
        c = self.start_pos.clone()
        for direction in self.directions:
            c.move(direction)
        return c

    @property
    def distance_to_end(self):
        c = self.end_pos
        return math.sqrt(
            abs(c.x-self.end_point.x)**2
            + abs(c.y-self.end_point.y)**2
        )

    @property
    def fitness_score(self):
        c = self.end_point

        # if reached goal
        if c == self.end_point:
            return 100000000 + 1 / len(self.directions)
        
        # if didnt reach goal
        if c != self.end_point:
            return 1 / self.distance_to_end


class population:
    def __init__(self, size, start: point, end: point, screen_size: point):
        self.size = size
        self.dots = []
        self.generation = 1
        for d in range(self.size):
            self.dots.append(dot(start, end, screen_size))

    def get_best_dot(self) -> dot:
        sorted_dots = sorted(self.dots, key=operator.attrgetter("fitness_score"))
        return sorted_dots[-1]

    def new_generation(self):
        best_dot = self.get_best_dot()
        self.dots = [best_dot]
        for d in range(self.size-1):
            mutated_dot = best_dot.clone()
            mutated_dot.mutate()
            self.dots.append(mutated_dot)
        self.generation += 1

    def draw(self, surface):
        draw_dots = self.dots.copy()
        draw_dots.remove(self.get_best_dot())
        for d in draw_dots:
            d.draw(surface, (255,255,255))
        self.get_best_dot().draw(surface, (255,0,0))