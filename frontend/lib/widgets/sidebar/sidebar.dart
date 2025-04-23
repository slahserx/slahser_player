SidebarItem(
  icon: Icons.cloud_outlined,
  selectedIcon: Icons.cloud,
  label: 'Subsonic',
  isSelected: widget.selectedIndex == 3,
  onTap: () => widget.onItemSelected(3),
), 