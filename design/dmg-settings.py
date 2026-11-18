# dmgbuild 설정: build.sh가 -D app=... -D background=... -D icon=... 로 경로를 넘긴다.
# 아이콘 자리는 DMGBackground.swift의 배경 그림(화살표 양끝)과 맞춰야 한다.
import os

application = defines["app"]
appname = os.path.basename(application)

format = "UDZO"
files = [application]
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]  # 마운트된 볼륨 아이콘

background = defines["background"]
# 창 크기는 위쪽 테두리(제목 표시줄, 최신 Finder는 무시하고 보이기도 하는 도구 막대)를 포함한다.
# 배경 그림은 660×460.
window_rect = ((200, 100), (660, 546))
default_view = "icon-view"
show_status_bar = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
arrange_by = None
icon_locations = {
    appname: (180, 200),
    "Applications": (480, 200),
}
