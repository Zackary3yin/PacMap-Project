%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% step6_0_segmentEEG_CPD_multiCenter.m
% 多中心模式：对所有中心执行变化点检测并保存 CPD 结果
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc; clear; close all;

% ———— 1. 定义根目录 & 中心列表 ————
projRoot = '/Users/yinziyuan/Desktop/PacMap Project/ICARE_GUI_modifications-main';
centers = {'UTW', 'MGH', 'BWH'};  % 可自定义中心列表

% 恢复 MATLAB 默认路径并添加工具路径
restoredefaultpath;
addpath(fullfile(projRoot, 'Tools'));
addpath(fullfile(projRoot, 'Tools', 'qEEG'));

% 检查必要函数是否存在
assert(~isempty(which('fcn_cpd')), '❌ 缺失 fcn_cpd');
assert(~isempty(which('fcn_computeSpec')), '❌ 缺失 fcn_computeSpec');

% ———— 2. CPD 参数 ————
Fs = 100;           % 采样率 Hz
alpha_cpd = 0.1;    % CPD 灵敏度

% ———— 3. 遍历所有中心 ————
for c = 1:length(centers)
    center = centers{c};
    fprintf('\n🌐 正在处理中心: %s\n', center);

    % 设置输入输出路径
    dataDir = fullfile(projRoot, 'eeg', center);
    specDir = fullfile(projRoot, 'GUI_results', center, 'Spectrograms1');
    outDir  = fullfile(projRoot, 'GUI_results', center, 'CPDs1');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    eegFiles = dir(fullfile(dataDir, '*.mat'));
    if isempty(eegFiles)
        fprintf('⚠️  中心 %s 无 EEG 文件，跳过\n', center);
        continue;
    end

    % 遍历该中心所有 EEG 文件
    for i = 1:numel(eegFiles)
        fileName = eegFiles(i).name;
        base = fileName(1:end-4);
        fprintf('(%d/%d) [%s] 处理文件: %s\n', i, numel(eegFiles), center, fileName);

        % 读取 EEG 长度
        Sx = load(fullfile(dataDir, fileName), 'x');
        if ~isfield(Sx, 'x')
            warning('❌ 文件中缺少 x 变量，跳过: %s', fileName);
            continue;
        end
        [~, N] = size(Sx.x.data);
        nn = ceil(N / (2 * Fs));  % 每 2 秒为一个窗口

        % 加载谱图并对齐长度
        specPath = fullfile(specDir, [base '_spect.mat']);
        if ~exist(specPath, 'file')
            warning('❌ 缺少谱图文件，跳过: %s', specPath);
            continue;
        end
        tmp = load(specPath, 'Sdata');
        Sdata = tmp.Sdata(:, 2);  % 提取第二个区域谱图

        mm = size(Sdata{1}, 2);
        if mm >= nn
            for kk = 1:numel(Sdata)
                Sdata{kk} = Sdata{kk}(:, 1:nn);
            end
        else
            dd1 = size(Sdata{1}, 1);
            dd2 = nn - mm;
            for kk = 1:numel(Sdata)
                Sdata{kk} = [Sdata{kk}, zeros(dd1, dd2)];
            end
        end

        % 变化点检测
        [isCPs, isCPcenters] = fcn_cpd(Sdata, alpha_cpd);

        % 构建 LUT
        idx_rise = find(isCPs);
        if isempty(idx_rise)
            lut_cpd = [1, 1, nn];
            isCPs = false(1, nn);
            isCPcenters = false(1, nn);
        else
            idx_fall = unique([idx_rise(2:end)-1; nn]);
            idx_cpc = idx_rise(:);
            m = numel(idx_rise);
            idx_fall = idx_fall(1:m);
            lut_cpd = [idx_cpc, idx_rise(:), idx_fall];
        end

        % 保存输出
        save(fullfile(outDir, [base '_cpc.mat']), 'isCPs', 'isCPcenters', 'lut_cpd', '-v7.3');
    end

    fprintf('✅ 中心 %s 完成 %d 个文件处理\n', center, numel(eegFiles));
end