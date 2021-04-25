import random
import math

class point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

class dot:
    def __init__(self, start: point, end: point):
        self.current_pos = start
        self.start_pos = start
        self.end_pos = end
        self.directions = []
        self.max_directions = 200
        self.speed = 5
        self.randomize()

    def randomize(self):
        for i in range(self.max_directions):
            rads = math.radians(random.randint(0, 360))
            p = point(math.cos(rads) * self.speed, math.sin(rads) * self.speed)
            self.directions.append(p)

    def clone(self):
        d = dot(self.start_pos, self.end_pos)
        d.directions = self.directions
        return d

    def mutate(self):
        for d in range(len(self.directions)):
            r = random.uniform(0, 1)
            if r < 0.01:
                rads = math.radians(random.randint(0, 360))
                direction = point(math.cos(rads) * self.speed, math.sin(rads) * self.speed)
                self.directions[d] = direction

class population:
    def __init__(self, size):
        self.size = size

    def calculate_fitness_everything(self):
        pass

    def get_best_dot(self):
        pass

    def new_generation(self):
        pass