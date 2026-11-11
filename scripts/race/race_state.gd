extends RefCounted
# 경기 화면 상태의 정본. 비교·대입에는 이 상수를 쓰고, 경기 조정자가 대입 값을 검증한다.
const MENU := "menu"
const COURSES := "courses"
const READY := "ready"
const SETTINGS := "settings"
const COUNTDOWN := "countdown"
const RACING := "racing"
const PAUSED := "paused"
const FINISHED := "finished"
const FAILED := "failed"
const ALL := [MENU,COURSES,READY,SETTINGS,COUNTDOWN,RACING,PAUSED,FINISHED,FAILED]
# 3D 화면을 가리는 불투명 메뉴 화면.
const MENUS := [MENU,COURSES,READY,SETTINGS]
# 차가 움직이는 상태(출발 카운트다운 포함).
const DRIVING := [COUNTDOWN,RACING]
# 완주하거나 시간이 끝난 결과 화면.
const ENDED := [FINISHED,FAILED]
