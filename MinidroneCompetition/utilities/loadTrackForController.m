function loadTrackForController()
% loadTrackForController - 从工程根目录 initData.mat 读取赛道, 刷新基础工作区参数:
%   trackWPs  : 2 x 11 航点矩阵 [x;y] (NED), 前 nSeg+1 列有效, 其余补 NaN
%   trackNSeg : 赛道段数 (标量)
% 供 flightControlSystem/Control System/Path Planning/pathStateMachine 的
% Parameter 数据使用. 已挂到 flightControlSystem 的 InitFcn, 每次仿真自动刷新;
% startVars.m 里也会调用一次.
% 找不到 initData.mat 时用 competitionScene.m 的默认 L 赛道.

MAXWP = 11;                       % 最多 10 段
wx = [0.5 2.45 2.45];             % 默认 L: 起点(0.5,1) 拐角(2.45,1) 线尾(2.45,3.0)
wy = [1.0 1.0  3.0 ];

f = '';
try
    p = slproject.getCurrentProject();
    if ~isempty(p)
        cand = fullfile(p.RootFolder, 'initData.mat');
        if isfile(cand)
            f = cand;
        end
    end
catch
end
if isempty(f)
    w = which('initData.mat');
    if ~isempty(w)
        f = w;
    elseif isfile('initData.mat')
        f = 'initData.mat';
    end
end

if ~isempty(f)
    try
        S = load(f);
        if isfield(S, 'Lines') && ~isempty(S.Lines)
            n = min(numel(S.Lines), MAXWP-1);
            tx = zeros(1, n+1);
            ty = zeros(1, n+1);
            tx(1) = S.Lines(1).StartX;
            ty(1) = S.Lines(1).StartY;
            for k = 1:n
                tx(k+1) = S.Lines(k).EndX;
                ty(k+1) = S.Lines(k).EndY;
            end
            wx = tx;
            wy = ty;
        end
    catch
        % 文件损坏时用默认赛道
    end
end

nSeg = numel(wx) - 1;
WPs = nan(2, MAXWP);
WPs(1, 1:nSeg+1) = wx;
WPs(2, 1:nSeg+1) = wy;

assignin('base', 'trackWPs', WPs);
assignin('base', 'trackNSeg', nSeg);
end
