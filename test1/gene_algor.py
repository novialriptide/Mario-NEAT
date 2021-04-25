import math
import random
import operator

def generate_tilemap(columns: int, rows: int):
    tm_contents = []
    for r in range(rows): 
        row = []
        for c in range(columns): 
            if random.random() > 0.1:
                row.append(0)
            else:
                row.append(1)
        tm_contents.append(row)
    
    return tm_contents

def print_tilemap(tilemap, highlighted_points=[]):
    for r in range(len(tilemap)):
        row = ""
        for c in range(len(tilemap[r])):
            if [c, r] not in highlighted_points:
                row += str(tilemap[r][c]) + " "
            else:
                row += "# "
        print(row)

class moveset:
    def __init__(self, mx: int, my: int):
        self.mx = mx
        self.my = my

class person:
    def __init__(self, x: int, y: int, tilemap, target_x: int, target_y: int):
        self.x = x
        self.y = y
        self.target_x = target_x
        self.target_y = target_y
        self.tilemap = tilemap
        self.number_of_moves = 0
        self.moveset = []
        self.fitness_points = 0
        self.is_alive = True
        self.purpose_achieved = False
        
    def calculate_distance_from_target(self):
        return math.sqrt(float(abs(self.target_x-self.x)^2 + abs(self.target_y-self.y)^2))

    def move(self, mx: int, my: int):
        if self.purpose_achieved == False and (mx != 0 and my != 0):
            old_distance = self.calculate_distance_from_target()
            if self.tilemap[self.y+my][self.x+mx] != 1 and self.x+mx >= 0 and self.y+my >= 0:
                self.x += mx
                self.y += my
                self.number_of_moves += 1
                self.moveset.append(moveset(mx, my))
                if old_distance > self.calculate_distance_from_target():
                    self.fitness_points += 10

    @property
    def moveset_string(self):
        result = ""
        for move in self.moveset:
            result += f"(x:{move.mx}, y:{move.my}), "
        
        return result

# Genetic Algorithm
def generate_random_moveset(person: person):
    chances = 5
    while(True):
        if chances == 0:
            person.is_alive = False
            break

        old_distance = person.calculate_distance_from_target()
        person.move(random.randint(-1,1),random.randint(-1,1))
        new_distance = person.calculate_distance_from_target()
        if old_distance < new_distance:
            chances -= 1
        if new_distance == 0:
            person.fitness_points += 200

def crossover(parent1: person, parent2: person, number_of_children: int):
    """
    Creates a child
    """
    moveset_template = []
    extra_moves = max(len(parent1.moveset), len(parent2.moveset)) - min(len(parent1.moveset), len(parent2.moveset))
    for move_id in range(min(len(parent1.moveset), len(parent2.moveset))):
        if (parent1.moveset[move_id].mx, parent1.moveset[move_id].my) == (parent2.moveset[move_id].mx, parent2.moveset[move_id].my):
            moveset_template.append(parent1.moveset[move_id])
        else:
            moveset_template.append(None)
    
    children = []
    for child in range(number_of_children):
        child_moveset = []
        for move_id in range(len(moveset_template)):
            if moveset_template[move_id] == None:
                child_moveset.append(moveset(random.randint(-1,1),random.randint(-1,1)))
        
        p = person(parent1.x, parent1.y, parent1.tilemap, parent1.target_x, parent1.target_y)
        for move in child_moveset:
            p.move(move.mx, move.my)
        children.append(p)

    return children

def mutate(parent: person, number_of_children: int):
    children = []
    for child in range(number_of_children):
        for move_id in range(len(parent.moveset)):
            child = person(parent.x, parent.y, parent.tilemap, parent.target_x, parent.target_y)
            child.moveset = parent.moveset
            if random.random() > 0.5:
                child.moveset[move_id] = moveset(random.randint(-1,1),random.randint(-1,1))
        
        children.append(child)

    return children

def draw_all_moves(person: person, x, y):
    for move in p.moveset:
        print_tilemap(tilemap, highlighted_points=[[x, y], [target_x, target_y]])
        x += move.mx
        y += move.my
        print(f"{move.mx}, {move.my}\n")

    print(f"Fitness Points: {p.fitness_points}\nisAlive: {p.is_alive}")