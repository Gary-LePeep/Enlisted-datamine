require daBfg
require DagorShaders
require DagorSystem
require danetlibs/renderer/includes/upscale_sampling
require ecs

let upscale_tex_gen_node_name = "upscale_tex_gen_node"
let upscale_tex_gen_node_entity = "upscale_node"

[bfg_ecs_node(name="upscale_tex_gen_node", entity="upscale_node", handle="node_handle")]
def register_upscale_tex_gen_node(var handle : NodeHandle& |#)
  handle <- registerNode(upscale_tex_gen_node_name) <| @(var registry : Registry)
    registry |> orderMeAfter("prepare_lights_node")
    registry |> orderMeBefore("combine_shadows_node")
    registry |> read("gbuf_depth") |> texture |> atStage(Stage POST_RASTER) |> bindToShaderVar("depth_gbuf")
    registry |> read("checkerboard_depth") |> texture |> atStage(Stage POST_RASTER) |> bindToShaderVar("downsampled_checkerboard_depth_tex")

    let upscaleInfo = [[Texture2dCreateInfo
      creationFlags = TEXCF_RTARGET | TEXFMT_R8,
      resolution = [[TextureResolution autoRes=[[AutoResolution name="main_view", multiplier=1.0]]]],
      mipLevels = 1u
    ]]
    let upscaleTexReq = registry |> create("upscale_sampling_tex", History No) |> texture(upscaleInfo) |> bindToShaderVar
    registry |> requestRenderPass |> color([[auto[] upscaleTexReq]])

    var upscaleTexHandle = upscaleTexReq |> handle
    return <- @ <| [[ <- upscaleTexHandle]]
      query() <| $ [es] (upscale_shader : PostFxRenderer)
        upscale_render(upscaleTexHandle |> view |> get_tex2d, upscale_shader)

[cpp_event(broadcast)]
struct OnRenderSettingsReady {}

[cpp_event(broadcast)]
struct AfterDeviceReset
  fullReset : bool

[es(on_event=AfterDeviceReset)]
def restoreWeights(evt : Event)
  query() <| $ [es] (var node_handle : NodeHandle&; upscale_weights_buffer : UniqueBufHolder)
    // Need to reregister node, because es will reset heap
    // with execute lambda in it.
    node_handle |> register_upscale_tex_gen_node
    upload_weights(upscale_weights_buffer)

[es(on_event=OnRenderSettingsReady, track=render_settings__upscaleSamplingTex)]
def init_upscale_node(evt : Event; render_settings__upscaleSamplingTex : bool; render_settings__fullDeferred : bool; render_settings__bare_minimum : bool)
  if render_settings__upscaleSamplingTex
    createEntitySync(upscale_tex_gen_node_entity)  <| $(init) //we should create this entity sync, because framegraph requere to know about this node immediately
      using() <| $(var handle : NodeHandle#)
        handle |> register_upscale_tex_gen_node
        init |> set("node_handle", handle)

    query() <| $ [es] (var upscale_weights_buffer : UniqueBufHolder)
      init_upscale(upscale_weights_buffer)
      upload_weights(upscale_weights_buffer)
  else
    destroyEntity(getSingletonEntity(upscale_tex_gen_node_entity))
    if render_settings__fullDeferred && !render_settings__bare_minimum
      logerr("upscale_node is mandatory for all presets except bare minimum, nswitch, mobile")