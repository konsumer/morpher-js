class MorpherJS.Morpher extends MorpherJS.EventDispatcher
  images: null
  triangles: []
  mesh: null

  totalWeight: 0
  
  canvas: null
  ctx: null
  tmpCanvas: null
  tmpCtx: null

  blendFunction: null

  requestID: null  

  constructor: (params = {}) ->
    @images = []
    @triangles = []
    @mesh = new MorpherJS.Mesh()
    
    @canvas = document.createElement('canvas')
    @ctx = @canvas.getContext('2d')
    @tmpCanvas = document.createElement('canvas')
    @tmpCtx = @tmpCanvas.getContext('2d')
    
    @blendFunction = params.blendFunction || MorpherJS.Morpher.defaultBlendFunction
    

  # images

  addImage: (image, params = {}) =>
    unless image instanceof MorpherJS.Image
      image = new MorpherJS.Image(image)
    if @images.length
      image.makeCompatibleWith @images[@images.length-1]
    @images.push image
    image.on 'load', @loadHandler
    image.on 'change', @changeHandler
    image.on 'point:add', @addPointHandler
    image.on 'point:remove', @removePointHandler
    image.on 'triangle:add', @addTriangleHandler
    image.on 'triangle:remove', @removeTriangleHandler
    image.on 'change', @draw
    @loadHandler()
    @trigger 'image:add' unless params.silent

  removeImage: (image) =>
    i = @images.indexOf image
    if i != -1
      delete @images.splice i, 1
      @trigger 'image:remove'

  loadHandler: (e) =>
    @draw()
    for image in @images
      return false unless image.el.width && image.el.height
    @trigger 'load', this, @canvas

  changeHandler: (e) =>
    @trigger 'change'


  # points

  addPoint: (x, y) =>
    for image in @images.concat @mesh
      image.addPoint x: x, y: y
    @trigger 'point:add', this

  addPointHandler: (image, point, pointParams = null) =>
    position = pointParams || image.getRelativePositionOf(point)
    for img in @images.concat @mesh
      if img.points.length < image.points.length
        img.addPoint position
        return
    @trigger 'point:add', this

  removePointHandler: (image, point, index) =>
    for img in @images.concat @mesh
      if img.points.length > image.points.length
        img.removePoint index
        return
    for triangle in @triangles
      for v, k in triangle
        triangle[k] -= 1 if v >= index
    @trigger 'point:remove', this


  # triangles

  addTriangle: (i1, i2, i3) =>
    if @images.length > 0
      @images[0].addTriangle i1, i2, i3

  triangleExists: (i1, i2, i3) =>
    for t in @triangles
      if t.indexOf(i1) != -1 && t.indexOf(i2) != -1 && t.indexOf(i3) != -1
        return true
    false

  addTriangleHandler: (image, i1, i2, i3, triangle) =>
    if image.triangles.length > @triangles.length && !@triangleExists(i1, i2, i3)
      @triangles.push [i1, i2, i3]
    for img in @images.concat @mesh
      if img.triangles.length < @triangles.length
        img.addTriangle i1, i2, i3
        return
    @trigger 'triangle:add', this

  removeTriangleHandler: (image, triangle, index) =>
    if image.triangles.length < @triangles.length
      delete @triangles.splice index, 1
    for img in @images.concat @mesh
      if img.triangles.length > @triangles.length
        img.removeTriangle index
        return
    @trigger 'triangle:remove', this
    

  # drawing

  draw: =>
    return if @requestID?
    requestFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame || window.msRequestAnimationFrame || window.oRequestAnimationFrame || window.webkitRequestAnimationFrame
    if requestFrame?
      @requestID = requestFrame @drawNow
    else
      @drawNow()

  drawNow: =>
    @canvas.width = @canvas.width
    @updateCanvasSize()
    @updateMesh()
    if @canvas.width > 0 && @canvas.height > 0 && @totalWeight > 0
      for image in @images
        @tmpCanvas.width = @tmpCanvas.width
        image.draw @tmpCtx, @mesh
        @blendFunction @ctx, @tmpCanvas, image.weight
      @trigger 'draw', this, @canvas
    @requestID = null

  updateCanvasSize: =>
    w = 0
    h = 0
    for image in @images
      w = Math.max image.el.width, w
      h = Math.max image.el.height, h
    if w != @canvas.width || h != @canvas.height
      @canvas.width = @tmpCanvas.width = w
      @canvas.height = @tmpCanvas.height = h
      for img in @images
        img.setMaxSize(w, h)
      @trigger 'resize', this, @canvas

  updateMesh: =>
    @totalWeight = 0
    @totalWeight += img.weight for img in @images
    for p, i in @mesh.points
      p.x = p.y = 0
      for img in @images
        p.x += img.points[i].x*img.weight/@totalWeight
        p.y += img.points[i].y*img.weight/@totalWeight

  @defaultBlendFunction: (destination, source, weight) =>
    dData = destination.getImageData(0, 0, source.width, source.height)
    sData = source.getContext('2d').getImageData(0, 0, source.width, source.height)
    for value, i in sData.data
      dData.data[i] += value*weight
    destination.putImageData dData, 0, 0


  # JSON

  toJSON: =>
    json = {}
    json.images = []
    for image in @images
      json.images.push image.toJSON()
    json.triangles = @triangles.slice()
    json


  fromJSON: (json = {}, params = {}) =>
    @reset() if params.hard
    if json.images?
      for image, i in json.images
        if i > @images.length - 1
          @addImage image, params
        else
          @images[i].fromJSON image, params
      @mesh.makeCompatibleWith(@images[0])
    if json.triangles?
      for triangle in json.triangles[@triangles.length..-1]
        @addTriangle triangle[0], triangle[1], triangle[2]
      

  reset: =>
    for image in @images
      @removeImage image
    @images = []


window.Morpher = MorpherJS.Morpher
