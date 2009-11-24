#!/usr/bin/env ruby

require 'wmlib'
require 'set'
require 'ostruct'

class Point
    attr_accessor :x,:y
    def initialize(x,y)
        @x = x
        @y = y
    end
    def <= (rhs)
        @x <= rhs.x && @y <=rhs.y
    end
    def / (rhs)
        Point.new(@x/rhs,@y/rhs)
    end
    def * (rhs)
        Point.new(@x*rhs,@y*rhs)
    end
    def + (rhs)
        Point.new(@x+rhs.x,@y+rhs.y)
    end
    def - (rhs)
        Point.new(@x-rhs.x,@y-rhs.y)
    end
    def direction()
        if @x>@y then
            if -@x>@y then
                :up
            else
                :right
            end
        else
            if -@x>@y then
                :left
            else
                :down
            end
        end
    end
    def length()
        Math.sqrt((@x*@x)+(@y*@y))
    end
    def to_s()
        "(#{@x},#{@y})"
    end
end

class Wnd
    attr_accessor :x1,:y1,:x2,:y2
    def initialize(w)
        @x1 = w.left
        @y1 = w.top
        @x2 = w.right
        @y2 = w.bottom
        @w = w
        @title = w.title
        @tl = Point.new(@x1,@y1)
        @br = Point.new(@x2,@y2)
    end

    # is the given region within this window?    
    def contains(x1,y1,x2,y2)
        @x1<=x1 && @y1<=y1 && x2<=@x2 && y2<=@y2
    end
    
    # size of the window
    def size
        (@x2-@x1)*(@y2-@y1)
    end
    
    def activate()
        @w.activate
    end
    
    def to_s()
        @title
    end
end

class Screen
    attr_accessor :xs,:ys,:windows,:screen
    def initialize(windows)
        @windows = windows
        # compute interesting boundaries
        @xs = windows.collect { |w| [w.x1,w.x2] }.flatten.sort.uniq
        @ys = windows.collect { |w| [w.y1,w.y2] }.flatten.sort.uniq
        # create 2D array of xs.size x ys.size 
        @screen = Array.new(@xs.size-1).collect { Array.new(@ys.size-1) }
        windows.each { |w|
            eachRegion { |x,y,wnd|
                @screen[x][y] = w  if  w.contains(@xs[x],@ys[y],@xs[x+1],@ys[y+1])
            }
        }
    end
    
    def eachRegion(&body)
        (0...(@ys.size-1)).each { |y|
            (0...(@xs.size-1)).each { |x|
                yield x,y,@screen[x][y]
            }
        }
    end
    
    def rectSize(x,y)
        (@xs[x+1]-@xs[x])*(@ys[y+1]-@ys[y])
    end
    
    def center(x,y)
        Point.new( (@xs[x+1]+@xs[x])/2 , (@ys[y+1]+@ys[y])/2 )
    end
end


# list up all windows that we care
# this enumerates windows from bottom to top
windows = []
WM::Window.each {|x|
    if !(["gnome-panel","desktop_window"].include? x.winclass) then
        windows << Wnd.new(x)
    end
}

s=Screen.new(windows)

# compute the center of gravity for visible region of each window
cog = windows.collect { |w|
    pixels = 0
    wp = Point.new(0,0)
    s.eachRegion { |x,y,wnd|
        if wnd==w then
            rs = s.rectSize(x,y)
            pixels += rs
            wp += s.center(x,y)*rs
        end
    }
    # puts "#{w} - #{wp/pixels} #{pixels}"
    
    OpenStruct.new({ :window => w, :center => wp/pixels, :size =>pixels })
}

# this is the current top-most window
cur = cog[-1]

# ignore windows that are mostly invisible
cog = cog.delete_if { |x| x.size<40000 }


if ARGV.size==0 then
    # diagnostic output
    puts "Current windows is #{cur.window}"
    cog.each { |w|
        relp = w.center-cur.center
        puts "  #{w.window} #{relp} #{relp.direction}"
    }
else
    target_dir = ARGV[0].to_sym
    t=cog.select{ |w|  # of the windows that are in the right direction
        w!=cur && (w.center-cur.center).direction==target_dir
    }.min{|a,b| # pick up the nearest one
        (a.center-cur.center).length <=> (b.center-cur.center).length
    }
    # if a suitable one is found, set focus
    if t!=nil then
        t.window.activate
    end
end

