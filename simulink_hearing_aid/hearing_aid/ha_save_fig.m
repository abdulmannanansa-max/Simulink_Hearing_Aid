function ha_save_fig(fig, path)
%HA_SAVE_FIG  Export a figure to PNG. print() on an invisible ('Visible','off') figure is a
%  known MATLAB pitfall on some graphics-driver/OS combinations (common on VMs and some remote
%  desktops) -- it can hang indefinitely rather than error, which is why it isn't just wrapped
%  in try/catch. exportgraphics with the software 'painters' renderer, set on the figure before
%  calling this, avoids that rendering path; it's used when available (R2020a+), falling back
%  to print() on older MATLAB. If export still fails or hangs, the plots are cosmetic only --
%  nothing else in RUN_ME depends on them, so re-run with figures skipped, or temporarily set
%  'Visible','on' wherever the figure is created to see what's actually happening on screen.
set(fig, 'Renderer', 'painters');
try
    if exist('exportgraphics', 'file')
        exportgraphics(fig, [path '.png'], 'Resolution', 110);
    else
        print(fig, path, '-dpng', '-r110', '-painters');
    end
catch err
    fprintf('(figure export failed for %s: %s)\n', path, err.message);
end
end
