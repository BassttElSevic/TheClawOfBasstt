function loadTrackForController()
% loadTrackForController - 从工程根目录 initData.mat 读取赛道, 刷新基础工作区参数:
%   trackWPs  : 2 x MAXWP 航点矩阵 [x;y] (NED), 前 nWPs 列有效, 其余补 NaN.
%               列 1..nSeg+1 为线段端点(起点 + 各段终点), 最后一列为终点圆圆心
%               (initData.Circle.X/Y), 即降落目标.
%   trackNSeg : 赛道线段数 (标量)
% 供 flightControlSystem/Control System/Path Planning/pathStateMachine 的
% Parameter 数据使用. 已挂到 flightControlSystem 的 InitFcn, 每次仿真自动刷新;
% startVars.m 里也会调用一次.
% 找不到 initData.mat 时用 competitionScene.m 的默认 L 赛道.

MAXWP = 22;                       % 最多 20 段 + 终点圆圆心, 其余列 NaN 填充
wx = [0.5 2.45 2.45 2.45];        % 默认 L: 起点(0.5,1) 拐角(2.45,1) 线尾(2.45,3.0) 圆心(2.45,3.2)
wy = [1.0 1.0 3.0 3.2];
nSeg = 2;

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
            nSeg = min(numel(S.Lines), MAXWP-2);
            tx = zeros(1, nSeg+1);
            ty = zeros(1, nSeg+1);
            tx(1) = S.Lines(1).StartX;
            ty(1) = S.Lines(1).StartY;
            for k = 1:nSeg
                tx(k+1) = S.Lines(k).EndX;
                ty(k+1) = S.Lines(k).EndY;
            end
            wx = tx;
            wy = ty;
        end
        % 终点圆圆心追加为最终航点(降落目标), 数据来自 initData.Circle, 不硬编码
        if isfield(S, 'Circle') && ~isempty(S.Circle)
            wx(end+1) = S.Circle.X;
            wy(end+1) = S.Circle.Y;
        end
    catch
        % 文件损坏时用默认赛道
    end
end

WPs = nan(2, MAXWP);
WPs(1, 1:numel(wx)) = wx;
WPs(2, 1:numel(wx)) = wy;

% initial XY position for the estimator frame (arena coordinates),
% read from initData.posNED - not hardcoded.
initPosXY = [0.5; 1.0];
if ~isempty(f)
    try
        S = load(f);
        if isfield(S, 'posNED') && numel(S.posNED) >= 2
            initPosXY = S.posNED(1:2)';
        end
    catch
    end
end
assignin('base', 'initPosXY', initPosXY);
assignin('base', 'trackWPs', WPs);
assignin('base', 'trackNSeg', nSeg);
end
