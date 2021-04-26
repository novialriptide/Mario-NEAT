"""
GAMEDEN REWRITE, developed by Andrew Hong
https://github.com/anbdrew
This is an engine primarily to store data for entities, 
tilemaps, and tilesets. It can do many other things such 
as casting rays, render text, and carry out button functions.

BUILD VER 4.23.2021.1
"""
try: import pygame
except ImportError: print("Error loading pygame, is it installed?")
try: import pymunk
except ImportError: print("Error loading pymunk, is it installed?")
import numpy
import os
import json
import math

_tilemap = {
    #contents[layer_number][row][column]
    "contents": None, "collision_layer": None, "invisible_layers": []
}

def _calculate_segment_intersection(x1,y1,x2,y2,x3,y3,x4,y4):
    exception_msg = "two lines inputted are parallel or coincident"

    dem = (x1-x2)*(y3-y4) - (y1-y2)*(x3-x4)
    if dem == 0:
        raise Exception(exception_msg)

    t1 = (x1-x3)*(y3-y4) - (y1-y3)*(x3-x4)
    t = t1/dem
    
    u1 = (x1-x2)*(y1-y3) - (y1-y2)*(x1-x3)
    u = -(u1/dem)

    if t >= 0 and t <= 1 and u >= 0 and u <= 1:
        Px = x1 + t*(x2-x1)
        Py = y1 + t*(y2-y1)
        return Px, Py
    else:
        raise Exception(exception_msg)

def convert_rect_to_wall(rect):
    return (rect.left, rect.top, rect.right, rect.top), (rect.left, rect.bottom, rect.right, rect.bottom), (rect.left, rect.top, rect.left, rect.bottom), (rect.right, rect.top, rect.right, rect.bottom)

def convert_rects_to_walls(rects):
    walls = []
    for rect in rects:
        wall_lines = convert_rect_to_wall(rect)
        for wall_line in range(len(wall_lines)):
            walls.append(wall_lines[wall_line])
    return walls

def get_ray_endpoint(coord1,coord2,walls):
    x1, y1 = coord1
    x2, y2 = coord2
    line_length = math.sqrt((x2-x1)**2 + (y2-y1)**2)
    highest_point = (x2, y2)
    highest_point_length = line_length
    for wall in walls:
        try:
            c = _calculate_segment_intersection(x1, y1, x2, y2, wall[0], wall[1], wall[2], wall[3])
            c_length = math.sqrt((x1-c[0])**2 + (y1-c[1])**2)
            if highest_point_length > c_length:
                highest_point = c
                highest_point_length = c_length
        except: pass
    return highest_point

def get_v_movement(degree,speed):
    radian = math.radians(degree) 
    x_distance = math.cos(radian)*speed
    y_distance = math.sin(radian)*speed
    return [x_distance, y_distance]

def text(text: str, size: int, sys_font: str, color: str):
    pygame.font.init()
    formatting = pygame.font.SysFont(sys_font,int(size))
    text_surface = formatting.render(text,True,color)
    return text_surface

def text2(text: str, size: int, font: str, color: str):
    pygame.font.init()
    formatting = pygame.font.Font(font,int(size))
    text_surface = formatting.render(text,True,color)
    return text_surface

def grayscale(img):
    arr = pygame.surfarray.array3d(img)
    #luminosity filter
    avgs = [[(r*0.298 + g*0.587 + b*0.114) for (r,g,b) in col] for col in arr]
    arr = numpy.array([[[avg,avg,avg] for avg in col] for col in avgs])
    return pygame.surfarray.make_surface(arr)

def genereate_tilemap(columns, rows):
    tm_contents = []
    row = []
    for c in range(columns): row.append(0)
    for r in range(rows): tm_contents.append(row.copy())
    
    tm = _tilemap.copy()
    tm["contents"] = [tm_contents]
    
    return tm

def convert_tiledjson(path):
    """Converts a tiled json map in GameDen's formatting"""
    with open(path, 'r') as file:
        loaded_json = json.load(file)

    contents = []
    for layer in range(len(loaded_json["layers"])):
        json_contents = loaded_json["layers"][layer]["data"]
        n = loaded_json["width"]
        layer_contents = [json_contents[i * n:(i + 1) * n] for i in range((len(json_contents) + n - 1) // n )]
        contents.append(layer_contents)
    tm = tilemap.copy()
    tm["contents"] = contents
    return tm

class button:
    def __init__(self, rect: pygame.Rect):
        self.rect = rect

    def is_hovering(self, mouse_position: tuple) -> bool:
        """If the position inputed is on top of the button, it'll return True"""
        return self.rect.collidepoint(mouse_position)

    def blit(self, surface: pygame.Surface, button_image: pygame.Surface):
        i_width, i_height = self.image.get_size()
        image = pygame.transform.scale(self.image,(i_width*self.scale_factor, i_height*self.scale_factor))
        surface.blit(image, (self.rect.x, self.rect.y))

class tileset:
    def __init__(self, textures_path: str, tile_size: tuple, tiles_distance: int=0):
        self.textures = pygame.image.load(textures_path)
        self.tile_size = tile_size
        self.tiles_distance = tiles_distance
        texSize = self.textures.get_size()
        tileSize = self.tile_size
        self.tileset_size = (int(texSize[0]/tileSize[0]), int(texSize[1]/tileSize[1]))

    def get_tile_id_pos(self,tile_id: int) -> tuple:
        """Returns the position of the inputed tile ID"""
        w_tileS, h_tileS = self.tile_size
        if (w_tileS*h_tileS) > tile_id:
            return (int(tile_id%w_tileS), int(tile_id/w_tileS))

    def blit(self,position: tuple, surface: pygame.Surface, tile_id: int):
        """Renders an image of a tile. tile_id can never be 0"""
        t_width, t_height = self.tile_size
        if tile_id != 0:
            tile_id = tile_id - 1

            # cropping
            tile = pygame.Surface(self.tile_size, pygame.SRCALPHA, 32).convert_alpha()
            t_x, t_y = self.get_tile_id_pos(tile_id)
            tile.blit(self.textures,(0,0),(t_width*t_x, t_height*t_y,t_width, t_height))
            surface.blit(tile,position)
        else: surface.blit(tile,position)

    def blit2(self, tile_id: int):
        """Returns an image of a tile. tile_id can never be 0"""
        tile = pygame.Surface(self.tile_size, pygame.SRCALPHA, 32)
        tile = tile.convert_alpha()
        if tile_id != 0:
            self.blit(tile, (0,0), tile_id)
            return tile
        else: return tile

class tileset2:
    def __init__(self, tileset_data: list, tile_size: tuple):
        """
        Tileset for solid colors, used mostly for debugging
        @param tileset_data: A list of rgb colors for tiles id starting from 1 and beyond
        @param tile_size: Size of the tiles
        """
        self.textures = None
        self.tileset_data = tileset_data
        self.tile_size = tile_size

    def get_tile_id_pos(self,tile_id: int):
        raise AttributeError("Doesn\'t exist, try using the original tileset class")

    def blit2(self, tile_id: int):
        """Renders an image of a tile. tile_id can never be 0"""
        tile = pygame.Surface(self.tile_size, pygame.SRCALPHA, 32).convert_alpha()
        if tile_id != 0:
            tile.fill(self.tileset_data[tile_id-1])
            return tile
        else: return tile

    def blit(self, position: tuple, surface: pygame.Surface, tile_id: int):
        """Returns the position of the inputed tile ID"""
        surface.blit(self.blit2(tile_id), position)

def add_rects_to_space(space: pymunk.Space, rects: list) -> list:
    """
    This function should executed ONCE
    @param space: Where the rects should be added
    @param rects: List of pygame rects to be convereted to pymunk rects
    """
    for rect in rects:
        def zero_gravity(body, gravity, damping, dt):
            pymunk.Body.update_velocity(body, (0,0), damping, dt)    
        _w, _h = rect[0].width, rect[0].height

        rect_b = pymunk.Body(1, 2, body_type=pymunk.Body.STATIC)
        rect_b.position = rect[0].x+_w/2, rect[0].y+_h/2
        rect_b.gameden = {"tile_id": rect[1]}
        rect_poly = pymunk.Poly(rect_b, [(-_w/2,-_h/2), (_w/2,-_h/2), (_w/2,_h/2), (-_w/2,_h/2)])
        rect_poly.friction = 0.8
        rect_poly.gameden = {"tile_id": rect[1]}
        space.add(rect_b, rect_poly)
        rect_b.velocity_func = zero_gravity

        rect.append(rect_b)
        rect.append(rect_poly)
        
    return rects

class tilemap:
    def __init__(self, map_data: dict, tileset=None, tile_distance=0):
        self.map_data = map_data
        map_contents = self.map_data["contents"]
        self.map_size = (len(map_contents[0][0]), len(map_contents[0]))
        self.tile_distance = tile_distance
    
        self.tileset = tileset
        self.tile_size = tileset.tile_size
        self.textures = tileset.textures

    def get_position_by_px(self, position: tuple) -> tuple:
        """
        Converts pixels on the screen to the tile position
        @param position: Pixels to Tile position
        """
        x_px, y_px = position
        t_width, t_height = self.tile_size
        m_width, m_height = self.map_size

        return ((t_width*m_width-x_px)/m_width, (t_height*m_width-y_px)/m_height)

    def set_tile_id(self, position: tuple, layer: int, tile_id: int):
        """
        Sets a position's tile id
        @param position: Determining which position you want to write
        @param layer: The position's layer you want to modify
        @param tile_id: The tile id you want to change to
        """
        column,row = position
        try: self.map_data["contents"][layer][row][column] = tile_id
        except TypeError: raise Exception(f"tile location doesn't exist ({column}, {row})")

    def get_tile_id(self, position: tuple, layer: int) -> int:
        """
        Returns a tile id from a specified position
        @param position: Determining which position you want to fetch
        @param layer: Which layer you want to use
        """
        column,row = position
        try: return self.map_data["contents"][layer][row][column]
        except TypeError: raise Exception(f"tile location doesn't exist ({column}, {row})")

    def get_collision_rects(self, position: tuple, layer: int, scale_factor: int = 1) -> list:
        """
        @param position: The anchor position
        @param layer: The collision layer
        @param scale_factor: The scale of the tiles
        """
        collision_rects = []
        a_x, a_y = position
        t_width, t_height = self.tile_size
        m_width, m_height = self.map_size

        y = 0
        for row in range(m_height):
            x = 0
            for column in range(m_width):
                tile_id = self.get_tile_id((column,row),layer)
                if tile_id != 0:
                    collision_rects.append([pygame.Rect(((a_x+x, a_y+y),(t_width*scale_factor, t_height*scale_factor))), tile_id])
                x += int(t_width*scale_factor)
            y += int(t_height*scale_factor)
        
        self.collision_rects = collision_rects
        return collision_rects

    def create_new_layer(self):
        self.tilemap["contents"].append([[0 for j in range(self.map_size[0])] for i in range(self.map_size[1])])
    
    def get_image_layer(self, layer_id: int):
        """
        @param layer_id: The layer that will be returned
        @param region1: The first set of coordinates that will determine how much of the map will be rendered
        @param region2: The second set of coordinates that will determine how much of the map will be rendered
        """
        t_width, t_height = self.tile_size
        m_width, m_height = self.map_size
        map_surface = pygame.Surface((t_width*m_width+self.tile_distance*m_width, t_height*m_height+self.tile_distance*m_height), pygame.SRCALPHA, 32).convert_alpha()
        
        for row in range(m_height):
            for column in range(m_width):
                tile_id = self.get_tile_id((column,row),layer_id)
                self.tileset.blit((column*t_width+self.tile_distance*(column-1), row*t_height+self.tile_distance*(row-1)), map_surface, tile_id)

        return map_surface

    def get_image_map(self):
        """
        @param region1: The first set of coordinates that will determine how much of the map will be rendered
        @param region2: The second set of coordinates that will determine how much of the map will be rendered
        """
        t_width, t_height = self.tile_size
        m_width, m_height = self.map_size
        map_surface = pygame.Surface((t_width*m_width+self.tile_distance*m_width, t_height*m_height+self.tile_distance*m_height), pygame.SRCALPHA, 32).convert_alpha()

        for layer in range(len(self.map_data["contents"])):
            if layer not in self.map_data["invisible_layers"]:
                map_surface.blit(self.get_image_layer(layer), (0,0))
        
        return map_surface

class entity:
    def __init__(self, body: pymunk.Body, size: tuple, tps: int=300, tilemap=None):
        """
        @param body: pymunk body
        @param size: width and height
        """
        self.tps = tps
        self.tilemap = tilemap

        # animations
        self.tick = 0
        self.current_texture = None
        self.image_offset_position = [0,0]

        # pymunk setup
        self.body = body
        self.width, self.height = size
        self.poly = pymunk.Poly(self.body, [(-self.width/2,-self.height/2), (self.width/2,-self.height/2), (self.width/2,self.height/2), (-self.width/2,self.height/2)])
    
    def set_position(self, position: tuple, tilemap):
        """
        @param position: the position you want to set
        @param tilemap: the tilemap
        """
        x, y = position
        m_x, m_y = tilemap.position
        t_width, t_height = tilemap.tile_size

        self.body.position[0] = m_x+t_width*tilemap.scale_factor*x
        self.body.position[1] = m_y+t_height*tilemap.scale_factor*y

class entity2:
    def __init__(self,rect,tps=300,map_class=None,render_size=1):
        self.entity_data = {"animation_sprites": {}}
        self.render_size = render_size
        self.tick = 0
        self.tps = tps
        self.map_class = map_class
        self.current_texture = None
        self.rect = rect
        self.image_offset_position = [0,0]
        self.position_float = [self.rect.x, self.rect.y]

    @property
    def image_size(self):
        return self.current_texture.get_rect().size

    @property
    def image_position(self):
        return [self.rect.x+self.image_offset_position[0], self.rect.y+self.image_offset_position[1]]

    @property
    def image_position_middle(self):
        return [
            int((self.rect.left + self.image_offset_position[0] + self.rect.right + self.image_offset_position[0])/2), 
            int((self.rect.bottom + self.image_offset_position[1] + self.rect.top + self.image_offset_position[1])/2)
        ]

    @property
    def size(self):
        return self.rect.size

    @property
    def position(self):
        return [self.rect.x, self.rect.y]

    @property
    def position_middle(self):
        return [int((self.rect.left + self.rect.right)/2), int((self.rect.bottom + self.rect.top)/2)]

    @property
    def position_offset(self):
        """WIP: Returns the entity's offset position to the tile they're standing on"""
        position_in_tiles = self.map_class.get_position(self.get_position())
        return (
            self.rect.x-(position_in_tiles[0]*self.map_class.tile_size[0]*self.map_class.render_size),
            self.rect.y-(position_in_tiles[1]*self.map_class.tile_size[1]*self.map_class.render_size)
        )

    def collision_test(self,rect,tiles):
        hit_list = []
        for tile in tiles:
            if rect.colliderect(tile):
                hit_list.append(tile)
        return hit_list

    def set_position(self,position):
        """Sets the entity's position to a specific position in pixels"""
        self.rect.x = position[0]
        self.rect.y = position[1]
        self.position_float = position
    
    def set_position2(self,position,tilemap):
        """Sets the entity's position to a specific position"""
        self.rect.x = tilemap.position[0]+tilemap.tile_size[0]*tilemap.render_size*position[0]
        self.rect.y = tilemap.position[1]+tilemap.tile_size[1]*tilemap.render_size*position[1]
        self.position_float = [self.rect.x, self.rect.y]

    def center(self,surface_size):
        """Centers the position"""
        surface_width, surface_height = surface_size
        map_size = self.map_rect.size
        self.rect.x = surface_width/2-map_size[0]/2,
        self.rect.y = surface_height/2-map_size[1]/2
        self.position_float = [self.rect.x, self.rect.y]

    def move(self,movement,obey_collisions=False,movement_accurate=False):
        """Moves the object relative from it's position"""
        if obey_collisions:
            collisions = self.map_class.collision_rects
        collision_types = {
            "top": False,
            "bottom": False,
            "right": False,
            "left": False
        }
        if movement_accurate:
            self.position_float[0] += movement[0]
            self.rect.x += movement[0] + (self.position_float[0] - self.rect.x)
        else:
            self.rect.x += movement[0]

        if obey_collisions:
            hit_list = self.collision_test(self.rect,collisions)
            for tile in hit_list:
                if movement[0] > 0:
                    self.rect.right = tile.left
                    collision_types["right"] = True
                elif movement[0] < 0:
                    self.rect.left = tile.right
                    collision_types["left"] = True

        if movement_accurate:
            self.position_float[1] += movement[1]
            self.rect.y += movement[1] + (self.position_float[1] - self.rect.y)
        else:
            self.rect.y += movement[1]

        if obey_collisions:
            hit_list = self.collision_test(self.rect,collisions)
            for tile in hit_list:
                if movement[1] > 0:
                    self.rect.bottom = tile.top
                    collision_types["bottom"] = True
                elif movement[1] < 0:
                    self.rect.top = tile.bottom
                    collision_types["top"] = True
        
        return collision_types

    def play_animation(self,animation_dict_name):
        """Starts the animation"""
        number_of_sprites = len(self.entity_data["animation_sprites"][animation_dict_name])
        if self.tick == number_of_sprites*self.tps:
            self.tick = 0
        try:
            self.current_texture = self.entity_data["animation_sprites"][str(animation_dict_name)][self.tick//self.tps]
            width, height = self.current_texture.get_size()
            self.current_texture = pygame.transform.scale(self.current_texture, (
                width*self.render_size,
                height*self.render_size
            ))
            self.rect = pygame.Rect(
                (self.rect.x, self.rect.y),
                (width*self.render_size,height*self.render_size)
            )
        except IndexError:
            raise Exception(f"sprite does not exist ({self.tick//self.tps})")
        except ZeroDivisionError:
            raise Exception(f"tps is invalid")

    def stop_animation(self):
        """Stops the animation"""
        self.tick = 0
    
    def new_animation_data(self,name,data):
        """Stores the entity's sprite information. Inside the data variable should be a list of the sprite images in order"""
        self.entity_data["animation_sprites"][str(name)] = data

    def pygame_render(self,surface):
        """Renders the entity's sprite"""
        surface.blit(self.current_texture,(
            self.rect.x+self.image_offset_position[0]*self.render_size, 
            self.rect.y+self.image_offset_position[1]*self.render_size
        ))

